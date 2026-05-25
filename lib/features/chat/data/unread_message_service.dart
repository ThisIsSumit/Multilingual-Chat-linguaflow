import '../../../core/services/checkpoint_service.dart';
import '../../chat/data/chat_repository.dart';

/// Service for calculating unread message counts using checkpoints
class UnreadMessageService {
  final ChatRepository _repository = ChatRepository();

  /// Get unread message count for a room using checkpoint
  /// Returns 0 if no checkpoint exists or if there's an error
  Future<int> getUnreadCount(String roomId) async {
    try {
      final checkpoint = await CheckpointService.getCheckpoint(roomId);

      if (checkpoint == null) {
        // No checkpoint = first time visiting, no unread messages
        return 0;
      }

      // Get count of messages since checkpoint
      final count = await _repository.getMessageCountSinceCheckpoint(
        roomId,
        checkpoint,
      );

      return count;
    } catch (e) {
      print('Error getting unread count for room $roomId: $e');
      return 0;
    }
  }

  /// Get unread counts for multiple rooms
  /// Returns map of roomId -> unreadCount
  Future<Map<String, int>> getUnreadCountsForRooms(List<String> roomIds) async {
    final results = <String, int>{};

    for (final roomId in roomIds) {
      results[roomId] = await getUnreadCount(roomId);
    }

    return results;
  }

  /// Get summary of unread messages across all rooms
  /// Returns total count of all unread messages
  Future<int> getTotalUnreadCount(List<String> roomIds) async {
    try {
      final counts = await getUnreadCountsForRooms(roomIds);
      return counts.values.fold<int>(0, (sum, count) => sum + count);
    } catch (_) {
      return 0;
    }
  }

  /// Check if a room has unread messages
  Future<bool> hasUnread(String roomId) async {
    final count = await getUnreadCount(roomId);
    return count > 0;
  }

  /// Mark all messages as read for a room by updating checkpoint
  Future<void> markRoomAsRead(String roomId) async {
    await CheckpointService.saveCheckpoint(roomId, DateTime.now());
  }

  /// Get checkpoint info for a room
  Future<CheckpointInfo?> getCheckpointInfo(String roomId) async {
    try {
      final checkpoint = await CheckpointService.getCheckpoint(roomId);
      final lastVisited = await CheckpointService.getLastVisited(roomId);

      if (checkpoint == null) return null;

      final unreadCount = await getUnreadCount(roomId);
      final secondsElapsed = DateTime.now().difference(checkpoint).inSeconds;

      return CheckpointInfo(
        roomId: roomId,
        checkpoint: checkpoint,
        lastVisited: lastVisited,
        unreadCount: unreadCount,
        secondsElapsed: secondsElapsed,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Data class for checkpoint information
class CheckpointInfo {
  final String roomId;
  final DateTime checkpoint;
  final DateTime? lastVisited;
  final int unreadCount;
  final int secondsElapsed;

  CheckpointInfo({
    required this.roomId,
    required this.checkpoint,
    this.lastVisited,
    required this.unreadCount,
    required this.secondsElapsed,
  });

  /// Human-readable format for display
  String get displayText => 'Last checked: $secondsElapsed seconds ago';

  /// Badge text showing unread count
  String get badgeText => unreadCount > 99 ? '99+' : unreadCount.toString();

  /// Whether to show unread badge
  bool get shouldShowBadge => unreadCount > 0;
}
