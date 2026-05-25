import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://172.17.51.141:3000';

  static String get socketUrl => baseUrl;

  // Auth
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String me = '/api/auth/me';

  // Rooms
  static const String rooms = '/api/rooms';
  static String roomById(String id) => '/api/rooms/$id';
  static const String joinRoom = '/api/rooms/join';
  static String roomMembers(String id) => '/api/rooms/$id/members';

  // Messages
  static String messages(String roomId) => '/api/rooms/$roomId/messages';
  static String messageCount(String roomId) =>
      '/api/rooms/$roomId/messages/count';

  // Connection timeouts
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;
  static const int maxRetries = 2;
}
