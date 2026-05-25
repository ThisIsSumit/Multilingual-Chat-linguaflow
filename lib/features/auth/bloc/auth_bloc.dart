import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/auth_repository.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/network/socket_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final SocketService _socketService;

  AuthBloc({
    required AuthRepository authRepository,
    required SocketService socketService,
  })  : _authRepository = authRepository,
        _socketService = socketService,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final token = await LocalStorage.getToken();
    if (token == null) {
      emit(const AuthUnauthenticated());
      return;
    }
    final user = await _authRepository.validateToken();
    if (user != null) {
      await LocalStorage.saveUserInfo(
        userId: user.id,
        username: user.username,
        preferredLanguage: user.preferredLanguage,
      );
      _socketService.connect(token);
      emit(AuthAuthenticated(user: user, token: token));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final result = await _authRepository.login(event.email, event.password);
      await LocalStorage.saveToken(result.token);
      await LocalStorage.saveUserInfo(
        userId: result.user.id,
        username: result.user.username,
        preferredLanguage: result.user.preferredLanguage,
      );
      _socketService.connect(result.token);
      emit(AuthAuthenticated(user: result.user, token: result.token));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final result = await _authRepository.register(
        username: event.username,
        email: event.email,
        password: event.password,
        preferredLanguage: event.preferredLanguage,
      );
      await LocalStorage.saveToken(result.token);
      await LocalStorage.saveUserInfo(
        userId: result.user.id,
        username: result.user.username,
        preferredLanguage: result.user.preferredLanguage,
      );
      _socketService.connect(result.token);
      emit(AuthAuthenticated(user: result.user, token: result.token));
    } catch (e) {
      emit(AuthError(_parseError(e)));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _socketService.disconnect();
    await LocalStorage.clearAll();
    emit(const AuthUnauthenticated());
  }

  String _parseError(dynamic e) {
    return e?.toString().replaceAll('DioException', '').trim() ??
        'An error occurred. Please try again.';
  }
}
