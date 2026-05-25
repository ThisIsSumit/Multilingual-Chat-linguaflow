import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/room_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class RoomMembersScreen extends StatelessWidget {
  final Room room;
  final List<RoomMember> members;

  const RoomMembersScreen({
    super.key,
    required this.room,
    required this.members,
  });

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
    final onlineMembers = members.where((m) => m.isOnline).toList();
    final offlineMembers = members.where((m) => !m.isOnline).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${AppStrings.members} (${members.length})',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        children: [
          if (onlineMembers.isNotEmpty) ...[
            _buildSectionHeader(context, '${AppStrings.online} — ${onlineMembers.length}'),
            ...onlineMembers.map((m) => _buildMemberTile(context, m)),
          ],
          if (offlineMembers.isNotEmpty) ...[
            _buildSectionHeader(context, '${AppStrings.offline2} — ${offlineMembers.length}'),
            ...offlineMembers.map((m) => _buildMemberTile(context, m)),
          ],
          if (members.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No members found',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, RoomMember member) {
    final flag = AppStrings.languageFlags[member.preferredLanguage] ?? '🌐';
    final initials = member.username.isNotEmpty
        ? member.username[0].toUpperCase()
        : '?';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _colorFromName(member.username),
            child: Text(
              initials,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: member.isOnline ? AppColors.onlineDot : AppColors.offlineDot,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        member.username,
        style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      subtitle: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            member.preferredLanguage,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: member.isOnline
              ? AppColors.onlineDot.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          member.isOnline ? AppStrings.online : AppStrings.offline2,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: member.isOnline ? AppColors.onlineDot : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
