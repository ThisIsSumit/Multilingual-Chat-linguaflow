import 'package:equatable/equatable.dart';
import '../models/message_model.dart';
import '../models/room_model.dart';

class ChatState extends Equatable {
  final List<Message> messages;
  final bool isLoading;
  final bool isSendingMessage;
  final bool hasMore;
  final Set<String> typingUserIds;
  final Map<String, String> typingUserNames;
  final String? error;
  final Set<String> showOriginalFor;
  final bool isConnected;
  final List<RoomMember> members;
  final Set<String> onlineUserIds;

  // Checkpoint tracking fields
  final DateTime? checkpointTime;
  final int newMessageCount;
  final bool isCheckpointLoaded;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSendingMessage = false,
    this.hasMore = true,
    this.typingUserIds = const {},
    this.typingUserNames = const {},
    this.error,
    this.showOriginalFor = const {},
    this.isConnected = true,
    this.members = const [],
    this.onlineUserIds = const {},
    // Checkpoint defaults
    this.checkpointTime,
    this.newMessageCount = 0,
    this.isCheckpointLoaded = false,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isSendingMessage,
    bool? hasMore,
    Set<String>? typingUserIds,
    Map<String, String>? typingUserNames,
    String? error,
    Set<String>? showOriginalFor,
    bool? isConnected,
    List<RoomMember>? members,
    Set<String>? onlineUserIds,
    DateTime? checkpointTime,
    int? newMessageCount,
    bool? isCheckpointLoaded,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      hasMore: hasMore ?? this.hasMore,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      typingUserNames: typingUserNames ?? this.typingUserNames,
      error: clearError ? null : error ?? this.error,
      showOriginalFor: showOriginalFor ?? this.showOriginalFor,
      isConnected: isConnected ?? this.isConnected,
      members: members ?? this.members,
      onlineUserIds: onlineUserIds ?? this.onlineUserIds,
      checkpointTime: checkpointTime ?? this.checkpointTime,
      newMessageCount: newMessageCount ?? this.newMessageCount,
      isCheckpointLoaded: isCheckpointLoaded ?? this.isCheckpointLoaded,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        isLoading,
        isSendingMessage,
        hasMore,
        typingUserIds,
        typingUserNames,
        error,
        showOriginalFor,
        isConnected,
        members,
        onlineUserIds,
        checkpointTime,
        newMessageCount,
        isCheckpointLoaded,
      ];
}
