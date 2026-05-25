import 'package:linguaflow/core/config/api_config.dart';
import 'package:linguaflow/core/network/dio_client.dart';
import 'package:linguaflow/core/storage/local_storage.dart';

class AuthUser {
  final String id;
  final String username;
  final String email;
  final String preferredLanguage;

  AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.preferredLanguage,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      preferredLanguage: json['preferredLanguage']?.toString() ?? 'English',
    );
  }
}

class AuthRepository {
  final _client = DioClient();

  Future<({String token, AuthUser user})> login(
      String email, String password) async {
    final response = await _client.post(
      ApiConfig.login,
      data: {'email': email, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    return (token: token, user: user);
  }

  Future<({String token, AuthUser user})> register({
    required String username,
    required String email,
    required String password,
    required String preferredLanguage,
  }) async {
    final response = await _client.post(
      ApiConfig.register,
      data: {
        'username': username,
        'email': email,
        'password': password,
        'preferredLanguage': preferredLanguage,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    return (token: token, user: user);
  }

  Future<AuthUser?> validateToken() async {
    try {
      final response = await _client.get(ApiConfig.me);
      final data = response.data as Map<String, dynamic>;
      return AuthUser.fromJson(data['user'] as Map<String, dynamic>? ?? data);
    } catch (_) {
      await LocalStorage.clearToken();
      return null;
    }
  }
}
