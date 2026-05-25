import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/chat_repository.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/services/checkpoint_service.dart';
import '../models/message_model.dart';
import '../models/room_model.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  final SocketService _socketService;
  String? _currentRoomId;

  StreamSubscription? _newMessageSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _typingStartSub;
  StreamSubscription? _typingStopSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _roomMemberJoinedSub;
  StreamSubscription? _userOnlineSub;
  StreamSubscription? _userOfflineSub;
  StreamSubscription? _messageSentAckSub;

  ChatBloc({
    required ChatRepository repository,
    required SocketService socketService,
  })  : _repository = repository,
        _socketService = socketService,
        super(const ChatState()) {
    on<LoadMessages>(_onLoadMessages);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<SendMessage>(_onSendMessage);
    on<MessageReceived>(_onMessageReceived);
    on<MessageStatusUpdated>(_onMessageStatusUpdated);
    on<TypingStarted>(_onTypingStarted);
    on<TypingStopped>(_onTypingStopped);
    on<ToggleMessageTranslation>(_onToggleTranslation);
    on<ConnectionStatusChanged>(_onConnectionChanged);
    on<SetRoomMembers>(_onSetRoomMembers);
    on<JoinRoom>(_onJoinRoom);
    on<LeaveRoom>(_onLeaveRoom);
    on<SocketMemberJoined>(_onSocketMemberJoined);
    on<SocketUserOnline>(_onSocketUserOnline);
    on<SocketUserOffline>(_onSocketUserOffline);

    // Checkpoint tracking handlers
    on<SaveCheckpoint>(_onSaveCheckpoint);
    on<LoadCheckpoint>(_onLoadCheckpoint);
    on<CheckMessagesSinceCheckpoint>(_onCheckMessagesSinceCheckpoint);
    on<ClearCheckpoint>(_onClearCheckpoint);
    on<MessageSentAck>(_onMessageSentAck);

    _subscribeToSocket();
  }

  void _subscribeToSocket() {
    _newMessageSub = _socketService.onNewMessage.listen((msg) {
      if (msg.roomId == _currentRoomId) {
        add(MessageReceived(msg));
      }
    });

    _statusSub = _socketService.onMessageStatus.listen((data) {
      add(MessageStatusUpdated(
        messageId: data['messageId']?.toString() ?? '',
        status: data['status']?.toString() ?? 'sent',
      ));
    });

    _typingStartSub = _socketService.onUserTyping.listen((data) {
      if (data['roomId']?.toString() == _currentRoomId) {
        add(TypingStarted(
          userId: data['userId']?.toString() ?? '',
          username: data['username']?.toString() ?? '',
        ));
      }
    });

    _typingStopSub = _socketService.onUserStopTyping.listen((data) {
      if (data['roomId']?.toString() == _currentRoomId) {
        add(TypingStopped(data['userId']?.toString() ?? ''));
      }
    });

    _roomMemberJoinedSub = _socketService.onRoomMemberJoined.listen((data) {
      if (data['roomId']?.toString() == _currentRoomId) {
        final user = data['user'];
        if (user is Map) {
          add(SocketMemberJoined(
            user: Map<String, dynamic>.from(user),
            roomId: data['roomId']?.toString() ?? '',
          ));
        }
      }
    });

    _userOnlineSub = _socketService.onUserOnline.listen((data) {
      if (data['roomId']?.toString() == _currentRoomId) {
        add(SocketUserOnline(data['userId']?.toString() ?? ''));
      }
    });

    _userOfflineSub = _socketService.onUserOffline.listen((data) {
      if (data['roomId']?.toString() == _currentRoomId) {
        add(SocketUserOffline(data['userId']?.toString() ?? ''));
      }
    });

    _connectionSub = _socketService.onConnectionChanged.listen((connected) {
      add(ConnectionStatusChanged(connected));
      if (connected && _currentRoomId != null) {
        _flushOfflineQueue();
      }
    });

    _messageSentAckSub = _socketService.onMessageSentAck.listen((data) {
      debugPrint('[CHAT_BLOC] Message sent ack received: $data');
      add(MessageSentAck(
        messageId: data['messageId']?.toString() ?? '',
        status: data['status']?.toString() ?? 'delivered',
      ));
    });
  }

  Future<void> _flushOfflineQueue() async {
    final queue = LocalStorage.getOfflineQueue();
    if (queue.isEmpty) return;

    await LocalStorage.clearOfflineQueue();
    for (final item in queue) {
      final roomId = item['roomId']?.toString();
      final text = item['text']?.toString();
      if (roomId != null && text != null) {
        _socketService.sendMessage(roomId, text);
      }
    }
  }

  Future<void> _onLoadMessages(
    LoadMessages event,
    Emitter<ChatState> emit,
  ) async {
    _currentRoomId = event.roomId;
    emit(state.copyWith(isLoading: true, clearError: true));

    // Load from cache first (unless skipCache is set)
    if (!event.skipCache) {
      final cached = LocalStorage.getCachedMessages(event.roomId);
      if (cached.isNotEmpty) {
        cached.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        emit(state.copyWith(messages: cached, isLoading: false));
      }
    }

    try {
      final messages = await _repository.getMessages(event.roomId);
      // Sort messages by createdAt (complete datetime: date + time)
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      await LocalStorage.cacheMessages(event.roomId, messages);
      // Only set hasMore to true if we got a full page (50+) of messages
      // If we got fewer than 50, we're at the end
      emit(state.copyWith(
        messages: messages,
        isLoading: false,
        hasMore: messages.length >= 50 && messages.isNotEmpty,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLoadMoreMessages(
    LoadMoreMessages event,
    Emitter<ChatState> emit,
  ) async {
    if (!state.hasMore || state.isLoading) return;
    emit(state.copyWith(isLoading: true));
    try {
      final older = await _repository.getMessages(
        event.roomId,
        beforeId: event.beforeMessageId,
      );

      // Deduplicate: filter out messages already in the list
      final existingIds = state.messages.map((m) => m.id).toSet();
      final newMessages =
          older.where((m) => !existingIds.contains(m.id)).toList();

      // Combine all messages and sort by createdAt (complete datetime: date + time)
      final combined = [...state.messages, ...newMessages];
      combined.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Stop loading if we got fewer than 50 items (reached the end)
      // or if no new messages were found
      final hasMoreMessages =
          newMessages.length >= 50 && newMessages.isNotEmpty;

      emit(state.copyWith(
        messages: combined,
        isLoading: false,
        hasMore: hasMoreMessages,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onMessageReceived(
    MessageReceived event,
    Emitter<ChatState> emit,
  ) async {
    // Find placeholder by matching the exact original text
    // This is how we identify our sent message's response from the server
    final placeholderIndex = state.messages.indexWhere((m) {
      return m.originalText == event.message.originalText &&
          m.id.startsWith('temp_'); // Definitely a placeholder
    });

    if (placeholderIndex >= 0) {
      // Replace placeholder with full message (with translations and delivered status)
      final updated = List<Message>.from(state.messages);
      final messageWithDeliveredStatus = event.message.copyWith(
        status: MessageStatus.delivered, // Double tick - now has translations
      );
      updated[placeholderIndex] = messageWithDeliveredStatus;
      // Re-sort to maintain chronological order (date + time)
      updated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      emit(state.copyWith(messages: updated));
      debugPrint(
          '[CHAT_BLOC] Placeholder replaced with full message with translations');
    } else if (!state.messages.any((m) => m.id == event.message.id)) {
      // New message from someone else or from backend sync
      // No placeholder, just add it and sort by createdAt
      final updated = [event.message, ...state.messages];
      updated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      emit(state.copyWith(messages: updated));
      debugPrint('[CHAT_BLOC] New message added from other user or sync');
    }
    // If message already exists as non-placeholder, don't duplicate

    if (_currentRoomId != null) {
      _socketService.markRead(_currentRoomId!);
    }
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ChatState> emit,
  ) async {
    // Create placeholder immediately with minimal data to show instantly
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final placeholderMessage = Message(
      id: tempMessageId,
      roomId: event.roomId,
      senderId: event.senderId.isNotEmpty ? event.senderId : 'current_user',
      senderUsername: 'You',
      originalText: event.text,
      detectedLanguage: 'Unknown',
      translations: {}, // Empty - no translations until server responds
      status: MessageStatus.sent, // Single tick
      createdAt: DateTime.now(),
    );

    // Emit placeholder IMMEDIATELY - don't wait for any async operations
    final updated = [placeholderMessage, ...state.messages];
    // Sort to maintain chronological order (date + time)
    updated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    emit(state.copyWith(messages: updated, isSendingMessage: true));

    // Send to server in background (don't wait for this)
    if (_socketService.isConnected) {
      _socketService.sendMessage(event.roomId, event.text);
    } else {
      await LocalStorage.queueOfflineMessage({
        'roomId': event.roomId,
        'text': event.text,
      });
    }

    emit(state.copyWith(isSendingMessage: false));
  }

  void _onMessageStatusUpdated(
    MessageStatusUpdated event,
    Emitter<ChatState> emit,
  ) {
    debugPrint(
        '[CHAT_BLOC] Updating message ${event.messageId} status to ${event.status}');
    final updated = state.messages.map((m) {
      if (m.id == event.messageId) {
        MessageStatus status;
        switch (event.status) {
          case 'delivered':
            status = MessageStatus.delivered;
            break;
          case 'read':
            status = MessageStatus.read;
            break;
          default:
            status = MessageStatus.sent;
        }
        debugPrint(
            '[CHAT_BLOC] Message ${event.messageId} status updated to $status');
        return m.copyWith(status: status);
      }
      return m;
    }).toList();
    emit(state.copyWith(messages: updated));
  }

  void _onTypingStarted(
    TypingStarted event,
    Emitter<ChatState> emit,
  ) {
    final ids = Set<String>.from(state.typingUserIds)..add(event.userId);
    final names = Map<String, String>.from(state.typingUserNames)
      ..[event.userId] = event.username;
    emit(state.copyWith(typingUserIds: ids, typingUserNames: names));
  }

  void _onTypingStopped(
    TypingStopped event,
    Emitter<ChatState> emit,
  ) {
    final ids = Set<String>.from(state.typingUserIds)..remove(event.userId);
    final names = Map<String, String>.from(state.typingUserNames)
      ..remove(event.userId);
    emit(state.copyWith(typingUserIds: ids, typingUserNames: names));
  }

  void _onToggleTranslation(
    ToggleMessageTranslation event,
    Emitter<ChatState> emit,
  ) {
    final set = Set<String>.from(state.showOriginalFor);
    if (set.contains(event.messageId)) {
      set.remove(event.messageId);
    } else {
      set.add(event.messageId);
    }
    emit(state.copyWith(showOriginalFor: set));
  }

  void _onConnectionChanged(
    ConnectionStatusChanged event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(isConnected: event.isConnected));
  }

  void _onSetRoomMembers(
    SetRoomMembers event,
    Emitter<ChatState> emit,
  ) {
    final normalized = event.members
        .map((member) =>
            member.copyWith(isOnline: state.onlineUserIds.contains(member.id)))
        .toList();
    emit(state.copyWith(members: normalized));
  }

  void _onJoinRoom(
    JoinRoom event,
    Emitter<ChatState> emit,
  ) {
    _currentRoomId = event.roomId;
    _socketService.joinRoom(event.roomId);
  }

  void _onLeaveRoom(
    LeaveRoom event,
    Emitter<ChatState> emit,
  ) {
    if (_currentRoomId == event.roomId) {
      _socketService.leaveRoom(event.roomId);
      _currentRoomId = null;
    }
  }

  void _onSocketMemberJoined(
    SocketMemberJoined event,
    Emitter<ChatState> emit,
  ) {
    final newMember = RoomMember.fromJson(event.user);
    if (state.members.any((m) => m.id == newMember.id)) return;
    emit(state.copyWith(members: [...state.members, newMember]));
  }

  void _onSocketUserOnline(
    SocketUserOnline event,
    Emitter<ChatState> emit,
  ) {
    final ids = {...state.onlineUserIds, event.userId};
    final members = state.members
        .map((member) => member.id == event.userId
            ? member.copyWith(isOnline: true)
            : member)
        .toList();
    emit(state.copyWith(onlineUserIds: ids, members: members));
  }

  void _onSocketUserOffline(
    SocketUserOffline event,
    Emitter<ChatState> emit,
  ) {
    final ids = {...state.onlineUserIds}..remove(event.userId);
    final members = state.members
        .map((member) => member.id == event.userId
            ? member.copyWith(isOnline: false)
            : member)
        .toList();
    emit(state.copyWith(onlineUserIds: ids, members: members));
  }

  // ===== Checkpoint Tracking Handlers =====

  Future<void> _onSaveCheckpoint(
    SaveCheckpoint event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await CheckpointService.saveCheckpoint(event.roomId, event.timestamp);
      emit(state.copyWith(checkpointTime: event.timestamp));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to save checkpoint: $e'));
    }
  }

  Future<void> _onLoadCheckpoint(
    LoadCheckpoint event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final checkpoint = await CheckpointService.getCheckpoint(event.roomId);
      if (checkpoint != null) {
        emit(state.copyWith(
          checkpointTime: checkpoint,
          isCheckpointLoaded: true,
        ));
      } else {
        emit(state.copyWith(isCheckpointLoaded: true));
      }
    } catch (e) {
      emit(state.copyWith(error: 'Failed to load checkpoint: $e'));
    }
  }

  void _onMessageSentAck(
    MessageSentAck event,
    Emitter<ChatState> emit,
  ) {
    debugPrint(
        '[CHAT_BLOC] Message sent ack: ${event.messageId} - waiting for translations...');
    // Only update to delivered when translations are available
    // The message will get translations from the new_message socket event
    // This handler serves as a confirmation that message reached backend
  }

  Future<void> _onCheckMessagesSinceCheckpoint(
    CheckMessagesSinceCheckpoint event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final checkpoint = await CheckpointService.getCheckpoint(event.roomId);
      if (checkpoint == null) {
        emit(state.copyWith(newMessageCount: 0));
        return;
      }

      // Count new messages since checkpoint
      final count = await _repository.getMessageCountSinceCheckpoint(
        event.roomId,
        checkpoint,
      );

      emit(state.copyWith(newMessageCount: count));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to check messages: $e'));
    }
  }

  Future<void> _onClearCheckpoint(
    ClearCheckpoint event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await CheckpointService.clearCheckpoint(event.roomId);
      emit(state.copyWith(
        checkpointTime: null,
        newMessageCount: 0,
      ));
    } catch (e) {
      emit(state.copyWith(error: 'Failed to clear checkpoint: $e'));
    }
  }

  void leaveCurrentRoom() {
    if (_currentRoomId != null) {
      _socketService.leaveRoom(_currentRoomId!);
      _currentRoomId = null;
    }
  }

  @override
  Future<void> close() {
    _newMessageSub?.cancel();
    _messageSentAckSub?.cancel();
    _statusSub?.cancel();
    _typingStartSub?.cancel();
    _typingStopSub?.cancel();
    _roomMemberJoinedSub?.cancel();
    _userOnlineSub?.cancel();
    _userOfflineSub?.cancel();
    _connectionSub?.cancel();
    leaveCurrentRoom();
    return super.close();
  }
}
