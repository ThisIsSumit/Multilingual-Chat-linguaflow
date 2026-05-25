import 'package:equatable/equatable.dart';
import '../../chat/models/room_model.dart';

abstract class RoomsEvent extends Equatable {
  const RoomsEvent();

  @override
  List<Object?> get props => [];
}

class LoadRooms extends RoomsEvent {
  const LoadRooms();
}

class CreateRoom extends RoomsEvent {
  final String name;

  const CreateRoom(this.name);

  @override
  List<Object?> get props => [name];
}

class JoinRoom extends RoomsEvent {
  final String code;

  const JoinRoom(this.code);

  @override
  List<Object?> get props => [code];
}

class RoomCreated extends RoomsEvent {
  final dynamic room;

  const RoomCreated(this.room);
}

class SocketRoomCreated extends RoomsEvent {
  final Room room;

  const SocketRoomCreated(this.room);

  @override
  List<Object?> get props => [room];
}

class SocketRoomMemberJoined extends RoomsEvent {
  final String roomId;
  final RoomMember user;

  const SocketRoomMemberJoined({required this.roomId, required this.user});

  @override
  List<Object?> get props => [roomId, user];
}

class SocketRoomListUpdated extends RoomsEvent {
  final String roomId;
  final Map<String, dynamic> lastMessage;
  final int unreadCount;

  const SocketRoomListUpdated({
    required this.roomId,
    required this.lastMessage,
    required this.unreadCount,
  });

  @override
  List<Object?> get props => [roomId, lastMessage, unreadCount];
}

class SocketUserOnline extends RoomsEvent {
  final String userId;
  final String roomId;

  const SocketUserOnline({required this.userId, required this.roomId});

  @override
  List<Object?> get props => [userId, roomId];
}

class SocketUserOffline extends RoomsEvent {
  final String userId;
  final String roomId;

  const SocketUserOffline({required this.userId, required this.roomId});

  @override
  List<Object?> get props => [userId, roomId];
}

class SocketUnreadCleared extends RoomsEvent {
  final String roomId;

  const SocketUnreadCleared(this.roomId);

  @override
  List<Object?> get props => [roomId];
}

class MarkRoomAsRead extends RoomsEvent {
  final String roomId;

  const MarkRoomAsRead(this.roomId);

  @override
  List<Object?> get props => [roomId];
}

class RefreshRoomsPeriodicly extends RoomsEvent {
  const RefreshRoomsPeriodicly();
}

// ===== Checkpoint-Based Unread Message Events =====

class UpdateUnreadCountsFromCheckpoint extends RoomsEvent {
  const UpdateUnreadCountsFromCheckpoint();
}

class UpdateSingleRoomUnreadCount extends RoomsEvent {
  final String roomId;

  const UpdateSingleRoomUnreadCount(this.roomId);

  @override
  List<Object?> get props => [roomId];
}

// class MarkRoomAsRead extends RoomsEvent {
//   final String roomId;

//   const MarkRoomAsRead(this.roomId);

//   @override
//   List<Object?> get props => [roomId];
// }

// class RefreshRoomsPeriodicly extends RoomsEvent {
//   const RefreshRoomsPeriodicly();
// }
