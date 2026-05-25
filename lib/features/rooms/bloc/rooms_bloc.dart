import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/services/checkpoint_service.dart';
import '../../chat/data/unread_message_service.dart';
import '../../chat/models/room_model.dart';
import '../data/rooms_repository.dart';
import 'rooms_event.dart';
import 'rooms_state.dart';

class RoomsBloc extends Bloc<RoomsEvent, RoomsState> {
  final RoomsRepository _repository;
  final SocketService _socketService;
  final UnreadMessageService _unreadService = UnreadMessageService();

  StreamSubscription? _roomCreatedSub;
  StreamSubscription? _roomMemberJoinedSub;
  StreamSubscription? _roomListUpdateSub;
  StreamSubscription? _userOnlineSub;
  StreamSubscription? _userOfflineSub;
  StreamSubscription? _unreadClearedSub;

  RoomsBloc(
      {required RoomsRepository repository,
      required SocketService socketService})
      : _repository = repository,
        _socketService = socketService,
        super(const RoomsInitial()) {
    on<LoadRooms>(_onLoadRooms);
    on<CreateRoom>(_onCreateRoom);
    on<JoinRoom>(_onJoinRoom);
    on<SocketRoomCreated>(_onSocketRoomCreated);
    on<SocketRoomMemberJoined>(_onSocketRoomMemberJoined);
    on<SocketRoomListUpdated>(_onSocketRoomListUpdated);
    on<SocketUserOnline>(_onSocketUserOnline);
    on<SocketUserOffline>(_onSocketUserOffline);
    on<SocketUnreadCleared>(_onSocketUnreadCleared);
    on<MarkRoomAsRead>(_onMarkRoomAsRead);
    on<RefreshRoomsPeriodicly>(_onRefreshRoomsPeriodicly);

    // Checkpoint-based unread counting
    on<UpdateUnreadCountsFromCheckpoint>(_onUpdateUnreadCountsFromCheckpoint);
    on<UpdateSingleRoomUnreadCount>(_onUpdateSingleRoomUnreadCount);

    _subscribeToSocket();
  }

  void _subscribeToSocket() {
    _roomCreatedSub = _socketService.onRoomCreated.listen((room) {
      add(SocketRoomCreated(room));
    });

    _roomMemberJoinedSub = _socketService.onRoomMemberJoined.listen((data) {
      final roomId = data['roomId']?.toString() ?? '';
      final userData = data['user'];
      if (roomId.isEmpty || userData is! Map) return;
      add(SocketRoomMemberJoined(
        roomId: roomId,
        user: RoomMember.fromJson(Map<String, dynamic>.from(userData)),
      ));
    });

    _roomListUpdateSub = _socketService.onRoomListUpdate.listen((data) {
      add(SocketRoomListUpdated(
        roomId: data['roomId']?.toString() ?? '',
        lastMessage: Map<String, dynamic>.from(data['lastMessage'] as Map),
        unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      ));
    });

    _userOnlineSub = _socketService.onUserOnline.listen((data) {
      add(SocketUserOnline(
        userId: data['userId']?.toString() ?? '',
        roomId: data['roomId']?.toString() ?? '',
      ));
    });

    _userOfflineSub = _socketService.onUserOffline.listen((data) {
      add(SocketUserOffline(
        userId: data['userId']?.toString() ?? '',
        roomId: data['roomId']?.toString() ?? '',
      ));
    });

    _unreadClearedSub = _socketService.onUnreadCleared.listen((roomId) {
      if (roomId.isNotEmpty) add(SocketUnreadCleared(roomId));
    });
  }

  List<Room> _sortRooms(List<Room> rooms) {
    final sorted = [...rooms];
    sorted.sort((a, b) {
      final aTime = a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  List<Room> _upsertRoom(List<Room> rooms, Room room, {bool prepend = false}) {
    final next = [...rooms.where((r) => r.id != room.id)];
    if (prepend) {
      next.insert(0, room);
    } else {
      next.add(room);
    }
    return _sortRooms(next);
  }

  Future<void> _onLoadRooms(
    LoadRooms event,
    Emitter<RoomsState> emit,
  ) async {
    emit(RoomsLoading(rooms: state.rooms, onlineUserIds: state.onlineUserIds));
    try {
      final rooms = await _repository.getRooms();
      emit(RoomsLoaded(rooms: rooms, onlineUserIds: state.onlineUserIds));
    } catch (e) {
      emit(RoomsError(e.toString(),
          rooms: state.rooms, onlineUserIds: state.onlineUserIds));
    }
  }

  Future<void> _onCreateRoom(
    CreateRoom event,
    Emitter<RoomsState> emit,
  ) async {
    emit(RoomCreating(rooms: state.rooms, onlineUserIds: state.onlineUserIds));
    try {
      final room = await _repository.createRoom(event.name);
      final updatedRooms = _upsertRoom(state.rooms, room, prepend: true);
      emit(RoomCreatedSuccess(
        room,
        rooms: updatedRooms,
        onlineUserIds: state.onlineUserIds,
      ));
    } catch (e) {
      emit(RoomsError(e.toString(),
          rooms: state.rooms, onlineUserIds: state.onlineUserIds));
    }
  }

  Future<void> _onJoinRoom(
    JoinRoom event,
    Emitter<RoomsState> emit,
  ) async {
    emit(RoomJoining(rooms: state.rooms, onlineUserIds: state.onlineUserIds));
    try {
      final room = await _repository.joinRoom(event.code);
      final updatedRooms = _upsertRoom(state.rooms, room, prepend: true);
      emit(RoomJoinedSuccess(
        room,
        rooms: updatedRooms,
        onlineUserIds: state.onlineUserIds,
      ));
    } catch (e) {
      emit(RoomJoinError(
        'Room not found. Check the code and try again.',
        rooms: state.rooms,
        onlineUserIds: state.onlineUserIds,
      ));
    }
  }

  void _onSocketRoomCreated(
    SocketRoomCreated event,
    Emitter<RoomsState> emit,
  ) {
    final updatedRooms = _upsertRoom(state.rooms, event.room, prepend: true);
    emit(RoomsLoaded(rooms: updatedRooms, onlineUserIds: state.onlineUserIds));
  }

  void _onSocketRoomMemberJoined(
    SocketRoomMemberJoined event,
    Emitter<RoomsState> emit,
  ) {
    final updatedRooms = state.rooms.map((room) {
      if (room.id != event.roomId) return room;
      final members = [...room.members];
      if (!members.any((member) => member.id == event.user.id)) {
        members.add(event.user);
      }
      return room.copyWith(
        members: members,
        totalMembers: members.length,
      );
    }).toList();
    emit(RoomsLoaded(rooms: updatedRooms, onlineUserIds: state.onlineUserIds));
  }

  void _onSocketRoomListUpdated(
    SocketRoomListUpdated event,
    Emitter<RoomsState> emit,
  ) {
    final updatedRooms = state.rooms.map((room) {
      if (room.id != event.roomId) return room;
      return room.copyWith(
        lastMessage: LastMessage.fromMap(event.lastMessage),
        unreadCount: event.unreadCount,
      );
    }).toList();
    emit(RoomsLoaded(
        rooms: _sortRooms(updatedRooms), onlineUserIds: state.onlineUserIds));
  }

  void _onSocketUserOnline(
    SocketUserOnline event,
    Emitter<RoomsState> emit,
  ) {
    final updatedOnlineIds = {...state.onlineUserIds, event.userId};
    emit(RoomsLoaded(rooms: state.rooms, onlineUserIds: updatedOnlineIds));
  }

  void _onSocketUserOffline(
    SocketUserOffline event,
    Emitter<RoomsState> emit,
  ) {
    final updatedOnlineIds = {...state.onlineUserIds}..remove(event.userId);
    emit(RoomsLoaded(rooms: state.rooms, onlineUserIds: updatedOnlineIds));
  }

  void _onSocketUnreadCleared(
    SocketUnreadCleared event,
    Emitter<RoomsState> emit,
  ) {
    final updatedRooms = state.rooms.map((room) {
      if (room.id != event.roomId) return room;
      return room.copyWith(unreadCount: 0);
    }).toList();
    emit(RoomsLoaded(rooms: updatedRooms, onlineUserIds: state.onlineUserIds));
  }

  void _onMarkRoomAsRead(
    MarkRoomAsRead event,
    Emitter<RoomsState> emit,
  ) {
    _socketService.markRead(event.roomId);
  }

  Future<void> _onRefreshRoomsPeriodicly(
    RefreshRoomsPeriodicly event,
    Emitter<RoomsState> emit,
  ) async {
    // Silent refresh - no loading state
    try {
      final rooms = await _repository.getRooms();
      emit(RoomsLoaded(rooms: rooms, onlineUserIds: state.onlineUserIds));
    } catch (e) {
      debugPrint('[RoomsBloc] Periodic refresh failed: $e');
    }
  }

  // ===== Checkpoint-Based Unread Message Handlers =====

  Future<void> _onUpdateUnreadCountsFromCheckpoint(
    UpdateUnreadCountsFromCheckpoint event,
    Emitter<RoomsState> emit,
  ) async {
    try {
      // Get unread counts for all rooms using checkpoints
      final roomIds = state.rooms.map((r) => r.id).toList();
      final unreadCounts =
          await _unreadService.getUnreadCountsForRooms(roomIds);

      // Update rooms with checkpoint-based unread counts
      final updatedRooms = state.rooms.map((room) {
        final newUnreadCount = unreadCounts[room.id] ?? 0;
        return room.copyWith(unreadCount: newUnreadCount);
      }).toList();

      emit(
          RoomsLoaded(rooms: updatedRooms, onlineUserIds: state.onlineUserIds));
    } catch (e) {
      debugPrint('[RoomsBloc] Error updating unread counts: $e');
    }
  }

  Future<void> _onUpdateSingleRoomUnreadCount(
    UpdateSingleRoomUnreadCount event,
    Emitter<RoomsState> emit,
  ) async {
    try {
      // Get unread count for single room
      final unreadCount = await _unreadService.getUnreadCount(event.roomId);

      // Update only the affected room
      final updatedRooms = state.rooms.map((room) {
        if (room.id != event.roomId) return room;
        return room.copyWith(unreadCount: unreadCount);
      }).toList();

      emit(
          RoomsLoaded(rooms: updatedRooms, onlineUserIds: state.onlineUserIds));
    } catch (e) {
      debugPrint('[RoomsBloc] Error updating room unread count: $e');
    }
  }

  @override
  Future<void> close() {
    _roomCreatedSub?.cancel();
    _roomMemberJoinedSub?.cancel();
    _roomListUpdateSub?.cancel();
    _userOnlineSub?.cancel();
    _userOfflineSub?.cancel();
    _unreadClearedSub?.cancel();
    return super.close();
  }
}
