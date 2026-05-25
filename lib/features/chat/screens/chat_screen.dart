import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../models/message_model.dart';
import '../models/room_model.dart';
import '../../rooms/bloc/rooms_bloc.dart';
import '../../rooms/bloc/rooms_event.dart' as rooms_events hide JoinRoom;
import '../../rooms/data/rooms_repository.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/widgets/loading_indicator.dart';

class ChatScreen extends StatefulWidget {
  final Room room;

  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  final GlobalKey<SliverAnimatedListState> _listKey = GlobalKey();
  final List<Message> _displayedMessages = [];
  late final ChatBloc _chatBloc;
  String _currentUserId = '';
  String _preferredLanguage = 'English';
  Timer? _typingTimer;
  Timer? _refreshTimer;
  bool _isTyping = false;
  List<RoomMember> _members = [];

  // Track keyboard height to add bottom padding to scroll view
  double _keyboardHeight = 0;

  @override
  void initState() {
    super.initState();
    _chatBloc = context.read<ChatBloc>();
    _chatBloc.add(JoinRoom(widget.room.id));
    _chatBloc.add(LoadMessages(widget.room.id));
    context.read<RoomsBloc>().add(rooms_events.MarkRoomAsRead(widget.room.id));
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);

    _focusNode.addListener(_onFocusChanged);

    _loadUserInfo();
    _loadMembers();

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        debugPrint('[CHAT_SCREEN] Periodic refresh - fetching fresh messages');
        _chatBloc.add(LoadMessages(widget.room.id, skipCache: true));
      }
    });
    if (mounted && !_isTyping && _messageController.text.isEmpty) {
      debugPrint('[CHAT_SCREEN] Periodic refresh - fetching fresh messages');
      _chatBloc.add(LoadMessages(widget.room.id, skipCache: true));
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // Wait for keyboard to fully slide up, then scroll to bottom
      Future.delayed(const Duration(milliseconds: 450), () {
        _scrollToBottom();
      });
    }
  }

  bool _listEqualsById(List<Message> a, List<Message> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  bool _listEqualsForDisplay(List<Message> a, List<Message> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.id != right.id ||
          left.originalText != right.originalText ||
          left.detectedLanguage != right.detectedLanguage ||
          left.status != right.status ||
          left.senderUsername != right.senderUsername ||
          left.createdAt != right.createdAt ||
          left.roomId != right.roomId ||
          left.senderId != right.senderId ||
          !mapEquals(left.translations, right.translations)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadUserInfo() async {
    final userId = await LocalStorage.getUserId();
    final lang = await LocalStorage.getPreferredLanguage();
    if (mounted) {
      setState(() {
        _currentUserId = userId ?? '';
        _preferredLanguage = lang;
      });
    }
  }

  Future<void> _loadMembers() async {
    try {
      final repo = RoomsRepository();
      final members = await repo.getRoomMembers(widget.room.id);
      if (mounted) {
        setState(() => _members = members);
        _chatBloc.add(SetRoomMembers(members));
      }
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 200) {
      final state = _chatBloc.state;
      if (!state.isLoading &&
          state.hasMore &&
          state.messages.isNotEmpty &&
          state.messages.length >= 50) {
        _chatBloc.add(LoadMoreMessages(
          roomId: widget.room.id,
          beforeMessageId: state.messages.first.id,
        ));
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && mounted) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onTextChanged() {
    final text = _messageController.text;
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      SocketService().startTyping(widget.room.id);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        SocketService().stopTyping(widget.room.id);
      }
    });
    setState(() {});
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    _isTyping = false;
    _typingTimer?.cancel();
    SocketService().stopTyping(widget.room.id);
    _chatBloc.add(SendMessage(
      roomId: widget.room.id,
      text: text,
      senderId: _currentUserId,
    ));
    debugPrint('[CHAT_SCREEN] Message sent - waiting for socket status events');
    // Scroll twice: once fast (moves most of the way), once after full layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _refreshTimer?.cancel();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _chatBloc.add(SaveCheckpoint(
      roomId: widget.room.id,
      timestamp: DateTime.now(),
    ));
    _chatBloc.add(LeaveRoom(widget.room.id));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Track keyboard height changes and scroll to bottom when keyboard opens
    final newKeyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    if (newKeyboardHeight > _keyboardHeight) {
      // Keyboard just opened or grew — scroll to bottom after layout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    _keyboardHeight = newKeyboardHeight;

    return BlocListener<ChatBloc, ChatState>(
      listenWhen: (prev, curr) =>
          !_listEqualsForDisplay(prev.messages, curr.messages) ||
          prev.showOriginalFor != curr.showOriginalFor ||
          prev.typingUserIds != curr.typingUserIds,
      listener: (context, state) {
        if (_listEqualsForDisplay(state.messages, _displayedMessages) &&
            state.typingUserIds.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 50), () {
              if (_scrollController.hasClients && mounted) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          });
          return;
        }
        final desired = List.of(state.messages);

        if (_displayedMessages.isEmpty && desired.isNotEmpty) {
          _displayedMessages.addAll(desired);
          // Post-frame so the list is built before we scroll
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
          return;
        }

        if (desired.length > _displayedMessages.length) {
          final newCount = desired.length - _displayedMessages.length;

          final possibleSuffix = desired.sublist(newCount);
          if (_displayedMessages.isNotEmpty &&
              possibleSuffix.length == _displayedMessages.length &&
              _listEqualsById(possibleSuffix, _displayedMessages)) {
            final prevMax = _scrollController.hasClients
                ? _scrollController.position.maxScrollExtent
                : 0.0;
            final prevOffset =
                _scrollController.hasClients ? _scrollController.offset : 0.0;

            for (int i = 0; i < newCount; i++) {
              _displayedMessages.insert(i, desired[i]);
              _listKey.currentState?.insertItem(i);
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                final newMax = _scrollController.position.maxScrollExtent;
                _scrollController.jumpTo(prevOffset + (newMax - prevMax));
              }
            });
            return;
          }

          final startIndex = _displayedMessages.length;
          for (int i = 0; i < newCount; i++) {
            final insertIndex = startIndex + i;
            _displayedMessages.insert(insertIndex, desired[insertIndex]);
            _listKey.currentState?.insertItem(insertIndex);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 80), _scrollToBottom);
          });

          return;
        }

        if (!_listEqualsForDisplay(desired, _displayedMessages)) {
          _displayedMessages
            ..clear()
            ..addAll(desired);
        }
      },
      child: Scaffold(
        // CRITICAL: must be true so the scaffold shrinks when keyboard opens
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            _buildOfflineBanner(),
            _buildChatHeader(),
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                reverse: false,
                // Add bottom padding equal to any extra safe-area so the last
                // message is never hidden behind the input bar
                slivers: [
                  _buildMessagesList(),
                  _buildLoadMoreIndicator(),
                  _buildTypingIndicator(),
                  // Extra breathing room at the bottom of the list
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (prev, curr) => prev.isConnected != curr.isConnected,
      builder: (context, state) {
        if (state.isConnected) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.orange.shade700,
          child: Text(
            AppStrings.offline,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedTitle() {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final onlineCount = _members.where((m) => m.isOnline).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.room.name,
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              '${_members.length} members · $onlineCount online',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChatHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(child: _buildCollapsedTitle()),
              IconButton(
                icon: const Icon(Icons.people_outline),
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/room-members',
                  arguments: {
                    'room': widget.room,
                    'members': _members,
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (prev, curr) =>
          !_listEqualsForDisplay(prev.messages, curr.messages) ||
          prev.showOriginalFor != curr.showOriginalFor,
      builder: (context, state) {
        if (state.isLoading && state.messages.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: LoadingIndicator()),
          );
        }

        if (state.messages.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Text(
                'Send the first message!',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        final displayed = _displayedMessages.isEmpty
            ? List.of(state.messages)
            : _displayedMessages;

        return SliverAnimatedList(
          key: _listKey,
          initialItemCount: displayed.length,
          itemBuilder: (context, index, animation) {
            if (index < 0 || index >= displayed.length) {
              return const SizedBox.shrink();
            }

            final message = displayed[index];
            final isMine = message.senderId == _currentUserId;
            final showOriginal = state.showOriginalFor.contains(message.id);

            final nextSenderId = index + 1 < displayed.length
                ? displayed[index + 1].senderId
                : null;
            final showSenderName = !isMine && nextSenderId != message.senderId;

            return SizeTransition(
              sizeFactor: animation,
              child: _MessageBubble(
                key: ValueKey(message.id),
                message: message,
                isMine: isMine,
                showSenderName: showSenderName,
                preferredLanguage: _preferredLanguage,
                showOriginal: showOriginal,
                onToggleTranslation: () => _chatBloc.add(
                  ToggleMessageTranslation(message.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (prev, curr) => prev.typingUserIds != curr.typingUserIds,
      builder: (context, state) {
        if (state.typingUserIds.isEmpty)
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && mounted) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
        final names = state.typingUserNames.values.take(2).join(', ');
        final label = state.typingUserIds.length == 1
            ? '$names ${AppStrings.isTyping}'
            : '$names ${AppStrings.areTyping}';

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _TypingDots(),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (prev, curr) => prev.isLoading != curr.isLoading,
      builder: (context, state) {
        if (!state.isLoading || state.messages.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: LoadingIndicator(size: 20)),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 90),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.inter(fontSize: 15),
                decoration: InputDecoration(
                  hintText: AppStrings.typeMessage,
                  hintStyle: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade900
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  counterText: _messageController.text.length > 200
                      ? '${_messageController.text.length}/500'
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasText ? AppColors.primary : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, size: 20),
                  color: Colors.white,
                  onPressed: hasText ? _sendMessage : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMine;
  final bool showSenderName;
  final String preferredLanguage;
  final bool showOriginal;
  final VoidCallback onToggleTranslation;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.showSenderName,
    required this.preferredLanguage,
    required this.showOriginal,
    required this.onToggleTranslation,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayText = widget.showOriginal
        ? widget.message.originalText
        : widget.message.translatedText(widget.preferredLanguage);

    final bubbleColor = widget.isMine
        ? AppColors.sentBubble
        : (isDark ? AppColors.receivedBubbleDark : AppColors.receivedBubble);

    final textColor = widget.isMine
        ? Colors.white
        : (isDark ? Colors.white : AppColors.textPrimary);

    final borderRadius = widget.isMine
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            mainAxisAlignment:
                widget.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                child: Column(
                  crossAxisAlignment: widget.isMine
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (widget.showSenderName && !widget.isMine)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 3),
                        child: Text(
                          widget.message.senderUsername,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: borderRadius,
                      ),
                      child: Column(
                        crossAxisAlignment: widget.isMine
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayText,
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 14.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(widget.message.createdAt),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: widget.isMine
                                      ? Colors.white60
                                      : AppColors.textSecondary,
                                ),
                              ),
                              if (widget.isMine) ...[
                                const SizedBox(width: 4),
                                _StatusIcon(status: widget.message.status),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${AppStrings.languageFlags[widget.message.detectedLanguage] ?? '🌐'} ${widget.message.detectedLanguage}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: widget.onToggleTranslation,
                            child: Text(
                              widget.showOriginal
                                  ? AppStrings.showTranslation
                                  : AppStrings.showOriginal,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time.toLocal());
  }
}

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.white60);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 12, color: Colors.white60);
      case MessageStatus.read:
        return const Icon(Icons.done_all,
            size: 12, color: AppColors.readReceipt);
    }
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _anims = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      final anim = Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
      _controllers.add(controller);
      _anims.add(anim);
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) controller.repeat(reverse: false);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (context, _) => Transform.translate(
            offset: Offset(0, _anims[i].value),
            child: Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: const BoxDecoration(
                color: AppColors.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
