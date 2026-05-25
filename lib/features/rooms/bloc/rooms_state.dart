import 'package:equatable/equatable.dart';
import '../../chat/models/room_model.dart';

abstract class RoomsState extends Equatable {
  final List<Room> rooms;
  final Set<String> onlineUserIds;

  const RoomsState({
    this.rooms = const <Room>[],
    this.onlineUserIds = const <String>{},
  });

  @override
  List<Object?> get props => [rooms, onlineUserIds];
}

class RoomsInitial extends RoomsState {
  const RoomsInitial(
      {super.rooms = const <Room>[], super.onlineUserIds = const <String>{}});
}

class RoomsLoading extends RoomsState {
  const RoomsLoading(
      {super.rooms = const <Room>[], super.onlineUserIds = const <String>{}});
}

class RoomsLoaded extends RoomsState {
  const RoomsLoaded(
      {required super.rooms, super.onlineUserIds = const <String>{}});
}

class RoomsError extends RoomsState {
  final String message;

  const RoomsError(
    this.message, {
    super.rooms = const <Room>[],
    super.onlineUserIds = const <String>{},
  });

  @override
  List<Object?> get props => [...super.props, message];
}

class RoomCreating extends RoomsState {
  const RoomCreating(
      {super.rooms = const <Room>[], super.onlineUserIds = const <String>{}});
}

class RoomCreatedSuccess extends RoomsState {
  final Room room;

  const RoomCreatedSuccess(
    this.room, {
    required super.rooms,
    super.onlineUserIds = const <String>{},
  });

  @override
  List<Object?> get props => [...super.props, room.id];
}

class RoomJoining extends RoomsState {
  const RoomJoining(
      {super.rooms = const <Room>[], super.onlineUserIds = const <String>{}});
}

class RoomJoinedSuccess extends RoomsState {
  final Room room;

  const RoomJoinedSuccess(
    this.room, {
    required super.rooms,
    super.onlineUserIds = const <String>{},
  });

  @override
  List<Object?> get props => [...super.props, room.id];
}

class RoomJoinError extends RoomsState {
  final String message;

  const RoomJoinError(
    this.message, {
    super.rooms = const <Room>[],
    super.onlineUserIds = const <String>{},
  });

  @override
  List<Object?> get props => [...super.props, message];
}
