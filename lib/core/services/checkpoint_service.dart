import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing checkpoint timestamps per room
/// Checkpoints track when a user last visited/viewed a room
/// This helps identify how many new messages arrived since then
class CheckpointService {
  static const String _checkpointPrefix = 'checkpoint_';
  static const String _lastVisitedPrefix = 'last_visited_';

  /// Save checkpoint timestamp for a room (when user exits/leaves room)
  static Future<void> saveCheckpoint(String roomId, DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_checkpointPrefix$roomId',
      timestamp.toIso8601String(),
    );
  }

  /// Get checkpoint timestamp for a room
  static Future<DateTime?> getCheckpoint(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('$_checkpointPrefix$roomId');
    if (stored == null) return null;
    try {
      return DateTime.parse(stored);
    } catch (_) {
      return null;
    }
  }

  /// Save the last visited/entered time for a room
  static Future<void> saveLastVisited(String roomId, DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_lastVisitedPrefix$roomId',
      timestamp.toIso8601String(),
    );
  }

  /// Get last visited time for a room
  static Future<DateTime?> getLastVisited(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('$_lastVisitedPrefix$roomId');
    if (stored == null) return null;
    try {
      return DateTime.parse(stored);
    } catch (_) {
      return null;
    }
  }

  /// Get time elapsed since checkpoint (in seconds)
  static Future<int> getSecondsSinceCheckpoint(String roomId) async {
    final checkpoint = await getCheckpoint(roomId);
    if (checkpoint == null) return 0;
    return DateTime.now().difference(checkpoint).inSeconds;
  }

  /// Clear checkpoint for a room
  static Future<void> clearCheckpoint(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_checkpointPrefix$roomId');
  }

  /// Clear all checkpoints
  static Future<void> clearAllCheckpoints() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_checkpointPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// Get all checkpoint timestamps
  static Future<Map<String, DateTime>> getAllCheckpoints() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final checkpoints = <String, DateTime>{};

    for (final key in keys) {
      if (key.startsWith(_checkpointPrefix)) {
        final roomId = key.replaceFirst(_checkpointPrefix, '');
        final timestamp = prefs.getString(key);
        if (timestamp != null) {
          try {
            checkpoints[roomId] = DateTime.parse(timestamp);
          } catch (_) {}
        }
      }
    }

    return checkpoints;
  }
}

/// Checkpoint data model for tracking message updates
class CheckpointData {
  final String roomId;
  final DateTime checkpointTime;
  final DateTime? lastVisitedTime;
  final int secondsElapsed;
  final int newMessageCount;
  final bool requiresBackendSync;

  CheckpointData({
    required this.roomId,
    required this.checkpointTime,
    this.lastVisitedTime,
    required this.secondsElapsed,
    required this.newMessageCount,
    this.requiresBackendSync = false,
  });

  String get checkpointFormatted =>
      checkpointTime.toString().split('.')[0]; // Remove microseconds

  String get summaryText =>
      'Last visited: $secondsElapsed seconds ago | New messages: $newMessageCount';
}
