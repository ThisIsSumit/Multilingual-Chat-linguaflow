import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthRegisterRequested extends AuthEvent {
  final String username;
  final String email;
  final String password;
  final String preferredLanguage;

  const AuthRegisterRequested({
    required this.username,
    required this.email,
    required this.password,
    required this.preferredLanguage,
  });

  @override
  List<Object?> get props => [username, email, password, preferredLanguage];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
