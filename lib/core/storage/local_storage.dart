import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/chat/models/message_model.dart';

class LocalStorage {
  static const String _tokenKey = 'jwt_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _preferredLanguageKey = 'preferred_language';
  static const String _offlineMessagesBox = 'offline_messages';
  static const String _cachedMessagesBox = 'cached_messages';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_offlineMessagesBox);
    await Hive.openBox<String>(_cachedMessagesBox);
  }

  // Auth token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // User info
  static Future<void> saveUserInfo({
    required String userId,
    required String username,
    required String preferredLanguage,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_preferredLanguageKey, preferredLanguage);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<String> getPreferredLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_preferredLanguageKey) ?? 'English';
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Offline message queue
  static Box<String> get _offlineBox => Hive.box<String>(_offlineMessagesBox);

  static Future<void> queueOfflineMessage(Map<String, dynamic> messageData) async {
    await _offlineBox.add(jsonEncode(messageData));
  }

  static List<Map<String, dynamic>> getOfflineQueue() {
    return _offlineBox.values
        .map((v) => jsonDecode(v) as Map<String, dynamic>)
        .toList();
  }

  static Future<void> clearOfflineQueue() async {
    await _offlineBox.clear();
  }

  // Message cache per room
  static Box<String> get _cacheBox => Hive.box<String>(_cachedMessagesBox);

  static Future<void> cacheMessages(String roomId, List<Message> messages) async {
    final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
    await _cacheBox.put(roomId, encoded);
  }

  static List<Message> getCachedMessages(String roomId) {
    final cached = _cacheBox.get(roomId);
    if (cached == null) return [];
    try {
      final list = jsonDecode(cached) as List;
      return list.map((m) => Message.fromJson(Map<String, dynamic>.from(m))).toList();
    } catch (_) {
      return [];
    }
  }
}
