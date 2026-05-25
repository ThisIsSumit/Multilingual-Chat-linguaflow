import 'package:linguaflow/core/config/api_config.dart';
import 'package:linguaflow/core/network/dio_client.dart';

import '../../chat/models/room_model.dart';

class RoomsRepository {
  final _client = DioClient();

  Future<List<Room>> getRooms() async {
    final response = await _client.get(ApiConfig.rooms);
    final data = response.data;
    final list = data is List ? data : (data['rooms'] as List? ?? []);
    return list
        .map((r) => Room.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<Room> createRoom(String name) async {
    final response = await _client.post(
      ApiConfig.rooms,
      data: {'name': name},
    );
    final data = response.data as Map<String, dynamic>;
    return Room.fromJson(data['room'] as Map<String, dynamic>? ?? data);
  }

  Future<Room> joinRoom(String code) async {
    final response = await _client.post(
      ApiConfig.joinRoom,
      data: {'code': code},
    );
    final data = response.data as Map<String, dynamic>;
    return Room.fromJson(data['room'] as Map<String, dynamic>? ?? data);
  }

  Future<List<RoomMember>> getRoomMembers(String roomId) async {
    final response = await _client.get(ApiConfig.roomMembers(roomId));
    final data = response.data;
    final list = data is List ? data : (data['members'] as List? ?? []);
    return list
        .map((m) => RoomMember.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}
