class Room {
  final String id;
  final String name;
  final String code;
  final LastMessage? lastMessage;
  final String? lastMessageLanguage;
  final int unreadCount;
  final int onlineCount;
  final int totalMembers;
  final List<RoomMember> members;

  Room({
    required this.id,
    required this.name,
    required this.code,
    this.lastMessage,
    this.lastMessageLanguage,
    this.unreadCount = 0,
    this.onlineCount = 0,
    this.totalMembers = 0,
    this.members = const [],
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    final lastMessageValue = json['lastMessage'];
    LastMessage? lastMessage;
    if (lastMessageValue is Map) {
      lastMessage =
          LastMessage.fromMap(Map<String, dynamic>.from(lastMessageValue));
    } else if (lastMessageValue != null) {
      lastMessage = LastMessage(
        text: lastMessageValue.toString(),
        senderId: json['lastMessageSenderId']?.toString() ?? '',
        senderUsername: json['lastMessageSenderUsername']?.toString() ?? '',
        createdAt: json['lastMessageAt'] != null
            ? DateTime.tryParse(json['lastMessageAt'].toString()) ??
                DateTime.now()
            : DateTime.now(),
      );
    }
    return Room(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      lastMessage: lastMessage,
      lastMessageLanguage: json['lastMessageLanguage']?.toString(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      onlineCount: (json['onlineCount'] as num?)?.toInt() ?? 0,
      totalMembers: (json['totalMembers'] as num?)?.toInt() ?? 0,
      members: (json['members'] as List?)
              ?.map((m) => RoomMember.fromJson(Map<String, dynamic>.from(m)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'lastMessage': lastMessage?.toJson(),
      'lastMessageAt': lastMessage?.createdAt.toIso8601String(),
      'unreadCount': unreadCount,
      'onlineCount': onlineCount,
      'totalMembers': totalMembers,
    };
  }

  Room copyWith({
    String? id,
    String? name,
    String? code,
    LastMessage? lastMessage,
    String? lastMessageLanguage,
    int? unreadCount,
    int? onlineCount,
    int? totalMembers,
    List<RoomMember>? members,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageLanguage: lastMessageLanguage ?? this.lastMessageLanguage,
      unreadCount: unreadCount ?? this.unreadCount,
      onlineCount: onlineCount ?? this.onlineCount,
      totalMembers: totalMembers ?? this.totalMembers,
      members: members ?? this.members,
    );
  }

  DateTime? get lastMessageAt => lastMessage?.createdAt;
}

class LastMessage {
  final String text;
  final String senderId;
  final String senderUsername;
  final DateTime createdAt;

  LastMessage({
    required this.text,
    required this.senderId,
    required this.senderUsername,
    required this.createdAt,
  });

  factory LastMessage.fromMap(Map<String, dynamic> data) {
    return LastMessage(
      text: data['text']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      senderUsername: data['senderUsername']?.toString() ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class RoomMember {
  final String id;
  final String username;
  final String preferredLanguage;
  final bool isOnline;

  RoomMember({
    required this.id,
    required this.username,
    required this.preferredLanguage,
    this.isOnline = false,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      preferredLanguage: json['preferredLanguage']?.toString() ?? 'English',
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }

  RoomMember copyWith({bool? isOnline}) {
    return RoomMember(
      id: id,
      username: username,
      preferredLanguage: preferredLanguage,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
