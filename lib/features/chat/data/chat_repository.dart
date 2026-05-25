import 'package:linguaflow/core/config/api_config.dart';
import 'package:linguaflow/core/network/dio_client.dart';

import '../../chat/models/message_model.dart';

class ChatRepository {
  final _client = DioClient();

  Future<List<Message>> getMessages(
    String roomId, {
    int limit = 50,
    String? beforeId,
    DateTime? sinceTimestamp,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (beforeId != null) params['before'] = beforeId;

    // Add checkpoint timestamp filter if provided
    // Backend should return only messages created after this timestamp
    if (sinceTimestamp != null) {
      params['since'] = sinceTimestamp.toIso8601String();
    }

    final response = await _client.get(
      ApiConfig.messages(roomId),
      queryParameters: params,
    );

    final data = response.data;
    final list = data is List ? data : (data['messages'] as List? ?? []);
    return list
        .map((m) => Message.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Fetch messages since a checkpoint timestamp
  /// Used to get only new messages since last visit
  Future<List<Message>> getMessagesSinceCheckpoint(
    String roomId,
    DateTime checkpointTime, {
    int limit = 50,
  }) async {
    return getMessages(
      roomId,
      limit: limit,
      sinceTimestamp: checkpointTime,
    );
  }

  /// Get message count since a checkpoint
  /// Useful for displaying unread message badge
  Future<int> getMessageCountSinceCheckpoint(
    String roomId,
    DateTime checkpointTime,
  ) async {
    try {
      final response = await _client.get(
        ApiConfig.messageCount(roomId),
        queryParameters: {
          'since': checkpointTime.toIso8601String(),
        },
      );

      if (response.data is Map) {
        final count = response.data['count'] ?? response.data['messageCount'];
        if (count is int) return count;
        if (count is num) return count.toInt();
      }

      return 0;
    } catch (_) {
      return 0;
    }
  }
}
