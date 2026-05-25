import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import '../../features/chat/models/message_model.dart';
import '../../features/chat/models/room_model.dart';

class SocketService {
  static SocketService? _instance;
  IO.Socket? _socket;

  final _newMessageController = StreamController<Message>.broadcast();
  final _messageStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _userTypingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _userStopTypingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _roomCreatedController = StreamController<Room>.broadcast();
  final _roomMemberJoinedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _roomListUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _userOnlineController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _userOfflineController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _unreadClearedController = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _messageSentAckController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Message> get onNewMessage => _newMessageController.stream;
  Stream<Map<String, dynamic>> get onMessageStatus =>
      _messageStatusController.stream;
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;
  Stream<Map<String, dynamic>> get onUserStopTyping =>
      _userStopTypingController.stream;
  Stream<Room> get onRoomCreated => _roomCreatedController.stream;
  Stream<Map<String, dynamic>> get onRoomMemberJoined =>
      _roomMemberJoinedController.stream;
  Stream<Map<String, dynamic>> get onRoomListUpdate =>
      _roomListUpdateController.stream;
  Stream<Map<String, dynamic>> get onUserOnline => _userOnlineController.stream;
  Stream<Map<String, dynamic>> get onUserOffline =>
      _userOfflineController.stream;
  Stream<String> get onUnreadCleared => _unreadClearedController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;
  Stream<Map<String, dynamic>> get onMessageSentAck =>
      _messageSentAckController.stream;

  bool get isConnected => _socket?.connected ?? false;

  SocketService._internal();

  factory SocketService() {
    _instance ??= SocketService._internal();
    return _instance!;
  }

  void connect(String token) {
    if (_socket?.connected == true) {
      debugPrint('[SOCKET] Already connected, skipping...');
      return;
    }

    debugPrint('[SOCKET] Initiating connection with token');
    _socket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[SOCKET] Connected');
      _connectionController.add(true);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[SOCKET] Disconnected');
      _connectionController.add(false);
    });

    _socket!.onConnectError((data) {
      debugPrint('[SOCKET] Connect error: $data');
      _connectionController.add(false);
    });

    _socket!.onError((data) {
      debugPrint('[SOCKET] Socket error: $data');
    });

    _socket!.onReconnect((_) {
      debugPrint('[SOCKET] Reconnected after disconnect');
      _connectionController.add(true);
    });

    _socket!.onReconnectError((data) {
      debugPrint('[SOCKET] Reconnect error: $data');
    });

    _socket!.on('new_message', (data) {
      try {
        final message = Message.fromJson(Map<String, dynamic>.from(data));
        _newMessageController.add(message);
      } catch (e) {
        debugPrint('[SOCKET] Error parsing message: $e');
      }
    });

    _socket!.on('message_sent_ack', (data) {
      debugPrint('[SOCKET] message_sent_ack event received: $data');
      _messageSentAckController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('message_status', (data) {
      debugPrint('[SOCKET] message_status event received: $data');
      _messageStatusController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('user_typing', (data) {
      _userTypingController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('user_stop_typing', (data) {
      _userStopTypingController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('user_online', (data) {
      debugPrint('[SOCKET] user_online event received: $data');
      _userOnlineController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('user_offline', (data) {
      debugPrint('[SOCKET] user_offline event received: $data');
      _userOfflineController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('room_created', (data) {
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        debugPrint('[SOCKET] room_created event received: $payload');
        _roomCreatedController.add(
            Room.fromJson(Map<String, dynamic>.from(payload['room'] as Map)));
      } catch (e) {
        debugPrint('[SOCKET] Error parsing room_created: $e');
      }
    });

    _socket!.on('room_member_joined', (data) {
      debugPrint('[SOCKET] room_member_joined event received: $data');
      _roomMemberJoinedController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('room_list_update', (data) {
      debugPrint('[SOCKET] room_list_update event received: $data');
      _roomListUpdateController.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.on('unread_cleared', (data) {
      final payload = Map<String, dynamic>.from(data as Map);
      debugPrint('[SOCKET] unread_cleared event received: $data');
      _unreadClearedController.add(payload['roomId']?.toString() ?? '');
    });
  }

  void disconnect() {
    debugPrint('[SOCKET] Disconnecting socket');
    _socket?.disconnect();
    _socket = null;
  }

  void forceReconnect(String token) {
    debugPrint('[SOCKET] Force reconnecting...');
    disconnect();
    Future.delayed(const Duration(milliseconds: 500), () {
      connect(token);
    });
  }

  void joinRoom(String roomId) {
    _socket?.emit('join_room', {'roomId': roomId});
  }

  void leaveRoom(String roomId) {
    _socket?.emit('leave_room', {'roomId': roomId});
  }

  void sendMessage(String roomId, String text) {
    _socket?.emit('send_message', {'roomId': roomId, 'text': text});
  }

  void startTyping(String roomId) {
    _socket?.emit('typing_start', {'roomId': roomId});
  }

  void stopTyping(String roomId) {
    _socket?.emit('typing_stop', {'roomId': roomId});
  }

  void markRead(String roomId) {
    _socket?.emit('mark_read', {'roomId': roomId});
  }

  void dispose() {
    _newMessageController.close();
    _messageStatusController.close();
    _userTypingController.close();
    _userStopTypingController.close();
    _roomCreatedController.close();
    _roomMemberJoinedController.close();
    _roomListUpdateController.close();
    _userOnlineController.close();
    _userOfflineController.close();
    _unreadClearedController.close();
    _connectionController.close();
    _socket?.dispose();
  }
}
