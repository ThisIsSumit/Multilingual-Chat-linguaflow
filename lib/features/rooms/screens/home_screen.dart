import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../bloc/rooms_bloc.dart';
import '../bloc/rooms_event.dart';
import '../bloc/rooms_state.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../chat/models/room_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/storage/local_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _username = '';
  String _preferredLanguage = 'English';
  String _currentUserId = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    context.read<RoomsBloc>().add(const LoadRooms());

    _loadUserInfo();

    // Fallback periodic refresh every 5 seconds if socket events aren't coming through
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        context.read<RoomsBloc>().add(const RefreshRoomsPeriodicly());
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final username = await LocalStorage.getUsername();
    final lang = await LocalStorage.getPreferredLanguage();
    final userId = await LocalStorage.getUserId();
    if (mounted) {
      setState(() {
        _username = username ?? '';
        _preferredLanguage = lang;
        _currentUserId = userId ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      },
      child: BlocListener<RoomsBloc, RoomsState>(
        listenWhen: (previous, current) =>
            current is RoomsLoaded &&
            current.rooms.isNotEmpty &&
            !identical(previous, current),
        listener: (context, state) async {
          // Wait 400ms to ensure SaveCheckpoint completes SharedPreferences write
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) {
            context
                .read<RoomsBloc>()
                .add(const UpdateUnreadCountsFromCheckpoint());
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.chats,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: -0.3,
                  ),
                ),
                if (_username.isNotEmpty)
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.onlineDot,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _username,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_outlined),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Logout',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      content: Text('Are you sure you want to logout?',
                          style: GoogleFonts.inter()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            context
                                .read<AuthBloc>()
                                .add(const AuthLogoutRequested());
                          },
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.error),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showRoomOptions(context),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: BlocBuilder<RoomsBloc, RoomsState>(
            builder: (context, state) {
              if (state is RoomsLoading) {
                if (state.rooms.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
              }

              if (state is RoomsError) {
                if (state.rooms.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(state.message, style: GoogleFonts.inter()),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () =>
                              context.read<RoomsBloc>().add(const LoadRooms()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
              }

              final rooms = state.rooms;
              final onlineUserIds = state.onlineUserIds;

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  context.read<RoomsBloc>().add(const LoadRooms());
                },
                child: rooms.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('💬',
                                    style: TextStyle(fontSize: 56)),
                                const SizedBox(height: 16),
                                Text(
                                  AppStrings.noRooms,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: rooms.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          indent: 72,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          return _RoomTile(
                            room: room,
                            preferredLanguage: _preferredLanguage,
                            currentUserId: _currentUserId,
                            onlineUserIds: onlineUserIds,
                            onRoomOpen: () {
                              context
                                  .read<RoomsBloc>()
                                  .add(MarkRoomAsRead(room.id));
                            },
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/chat',
                              arguments: room,
                            ),
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showRoomOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_circle_outline,
                    color: AppColors.primary),
              ),
              title: Text(AppStrings.createRoom,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              subtitle: Text('Start a new chat room',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/create-room');
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.login_outlined, color: AppColors.primary),
              ),
              title: Text(AppStrings.joinRoom,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              subtitle: Text('Enter a room code to join',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/join-room');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Room room;
  final String preferredLanguage;
  final String currentUserId;
  final Set<String> onlineUserIds;
  final VoidCallback onRoomOpen;
  final VoidCallback onTap;

  const _RoomTile({
    required this.room,
    required this.preferredLanguage,
    required this.currentUserId,
    required this.onlineUserIds,
    required this.onRoomOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _RoomAvatar(name: room.name),
      title: Row(
        children: [
          Expanded(
            child: Text(
              room.name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (room.lastMessageAt != null)
            Text(
              _formatTime(room.lastMessageAt!),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: room.unreadCount > 0
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight:
                    room.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  room.lastMessage?.text ?? 'No messages yet',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: room.unreadCount > 0
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (room.unreadCount > 0)
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.indigo,
                  child: Text(
                    room.unreadCount > 99 ? '99+' : room.unreadCount.toString(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                room.code,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.primary.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: room.members.any((member) {
                    if (member.id == currentUserId) return false;
                    return onlineUserIds.contains(member.id);
                  })
                      ? AppColors.onlineDot
                      : AppColors.offlineDot,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${room.members.where((member) => member.id != currentUserId && onlineUserIds.contains(member.id)).length} online',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        onRoomOpen();
        onTap();
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(time);
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('dd/MM').format(time);
  }
}

class _RoomAvatar extends StatelessWidget {
  final String name;

  const _RoomAvatar({required this.name});

  Color _colorFromName(String name) {
    final colors = [
      const Color(0xFF3D5AFE),
      const Color(0xFF00BCD4),
      const Color(0xFF4CAF50),
      const Color(0xFFFF5722),
      const Color(0xFF9C27B0),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF009688),
    ];
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';

    return CircleAvatar(
      radius: 26,
      backgroundColor: _colorFromName(name),
      child: Text(
        initials,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}
