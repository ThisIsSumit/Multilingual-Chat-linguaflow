import 'package:equatable/equatable.dart';
import '../models/message_model.dart';
import '../models/room_model.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadMessages extends ChatEvent {
  final String roomId;
  final bool skipCache;

  const LoadMessages(this.roomId, {this.skipCache = false});

  @override
  List<Object?> get props => [roomId, skipCache];
}

class SetRoomMembers extends ChatEvent {
  final List<RoomMember> members;

  const SetRoomMembers(this.members);

  @override
  List<Object?> get props => [members];
}

class JoinRoom extends ChatEvent {
  final String roomId;

  const JoinRoom(this.roomId);

  @override
  List<Object?> get props => [roomId];
}

class LeaveRoom extends ChatEvent {
  final String roomId;

  const LeaveRoom(this.roomId);

  @override
  List<Object?> get props => [roomId];
}

class LoadMoreMessages extends ChatEvent {
  final String roomId;
  final String beforeMessageId;

  const LoadMoreMessages({required this.roomId, required this.beforeMessageId});

  @override
  List<Object?> get props => [roomId, beforeMessageId];
}

class SendMessage extends ChatEvent {
  final String roomId;
  final String text;
  final String senderId;

  const SendMessage({
    required this.roomId,
    required this.text,
    required this.senderId,
  });

  @override
  List<Object?> get props => [roomId, text, senderId];
}

class MessageReceived extends ChatEvent {
  final Message message;

  const MessageReceived(this.message);

  @override
  List<Object?> get props => [message.id];
}

class MessageStatusUpdated extends ChatEvent {
  final String messageId;
  final String status;

  const MessageStatusUpdated({required this.messageId, required this.status});

  @override
  List<Object?> get props => [messageId, status];
}

class TypingStarted extends ChatEvent {
  final String userId;
  final String username;

  const TypingStarted({required this.userId, required this.username});

  @override
  List<Object?> get props => [userId, username];
}

class TypingStopped extends ChatEvent {
  final String userId;

  const TypingStopped(this.userId);

  @override
  List<Object?> get props => [userId];
}

class ToggleMessageTranslation extends ChatEvent {
  final String messageId;

  const ToggleMessageTranslation(this.messageId);

  @override
  List<Object?> get props => [messageId];
}

class ConnectionStatusChanged extends ChatEvent {
  final bool isConnected;

  const ConnectionStatusChanged(this.isConnected);

  @override
  List<Object?> get props => [isConnected];
}

class SocketMemberJoined extends ChatEvent {
  final Map<String, dynamic> user;
  final String roomId;

  const SocketMemberJoined({required this.user, required this.roomId});

  @override
  List<Object?> get props => [user, roomId];
}

class SocketUserOnline extends ChatEvent {
  final String userId;

  const SocketUserOnline(this.userId);

  @override
  List<Object?> get props => [userId];
}

class SocketUserOffline extends ChatEvent {
  final String userId;

  const SocketUserOffline(this.userId);

  @override
  List<Object?> get props => [userId];
}

// ===== Checkpoint Tracking Events =====

class SaveCheckpoint extends ChatEvent {
  final String roomId;
  final DateTime timestamp;

  const SaveCheckpoint({required this.roomId, required this.timestamp});

  @override
  List<Object?> get props => [roomId, timestamp];
}

class MessageSentAck extends ChatEvent {
  final String messageId;
  final String status;

  const MessageSentAck({required this.messageId, required this.status});

  @override
  List<Object?> get props => [messageId, status];
}

class LoadCheckpoint extends ChatEvent {
  final String roomId;

  const LoadCheckpoint(this.roomId);

  @override
  List<Object?> get props => [roomId];
}

class CheckMessagesSinceCheckpoint extends ChatEvent {
  final String roomId;

  const CheckMessagesSinceCheckpoint(this.roomId);

  @override
  List<Object?> get props => [roomId];
}

class ClearCheckpoint extends ChatEvent {
  final String roomId;

  const ClearCheckpoint(this.roomId);

  @override
  List<Object?> get props => [roomId];
}
