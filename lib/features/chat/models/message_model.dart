enum MessageStatus { sent, delivered, read }

class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String senderUsername;
  final String originalText;
  final String detectedLanguage;
  final Map<String, String> translations;
  final MessageStatus status;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderUsername,
    required this.originalText,
    required this.detectedLanguage,
    required this.translations,
    required this.status,
    required this.createdAt,
  });

  String translatedText(String preferredLanguage) {
    if (translations.isEmpty) return originalText;

    // Exact match
    if (translations.containsKey(preferredLanguage)) {
      return translations[preferredLanguage]!;
    }

    // Case-insensitive lookup
    final key = translations.keys.firstWhere(
      (k) => k.toLowerCase() == preferredLanguage.toLowerCase(),
      orElse: () => '',
    );
    if (key.isNotEmpty) return translations[key]!;

    // Partial match (e.g., 'English (US)' vs 'English')
    final partial = translations.keys.firstWhere(
      (k) => k.toLowerCase().contains(preferredLanguage.toLowerCase()),
      orElse: () => '',
    );
    if (partial.isNotEmpty) return translations[partial]!;

    // Fallback to first available translation
    return translations.values.first;
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] ?? json['Id'])?.toString() ?? '',
      roomId:
          (json['roomId'] ?? json['room_id'] ?? json['roomId'])?.toString() ??
              '',
      senderId: (json['senderId'] ?? json['sender_id'])?.toString() ?? '',
      senderUsername: (json['senderUsername'] ??
                  json['sender_username'] ??
                  json['username'] ??
                  json['sender']?['username'])
              ?.toString() ??
          'Unknown',
      originalText:
          (json['originalText'] ?? json['original_text'] ?? json['text'])
                  ?.toString() ??
              '',
      detectedLanguage:
          (json['detectedLanguage'] ?? json['detected_language'])?.toString() ??
              'English',
      translations: _parseTranslations(json['translations']),
      status: _parseStatus(json['status']?.toString()),
      createdAt: _parseCreatedAt(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'originalText': originalText,
      'detectedLanguage': detectedLanguage,
      'translations': translations,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Message copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderUsername,
    String? originalText,
    String? detectedLanguage,
    Map<String, String>? translations,
    MessageStatus? status,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      originalText: originalText ?? this.originalText,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      translations: translations ?? this.translations,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static MessageStatus _parseStatus(String? status) {
    switch (status) {
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      default:
        return MessageStatus.sent;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Message && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

Map<String, String> _parseTranslations(dynamic raw) {
  if (raw == null) return {};
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }
  return {};
}

DateTime _parseCreatedAt(dynamic raw) {
  if (raw == null) return DateTime.now();
  try {
    final s = raw.toString();
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt;
    // try parsing as int millis since epoch
    final millis = int.tryParse(s);
    if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
  } catch (_) {}
  return DateTime.now();
}
