
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onAuthCheckRequested);
  }

  // Xử lý sự kiện đăng nhập
  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final session = await _authRepository.login(
        email: event.email,
        password: event.password,
      );
      emit(Authenticated(session));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  // Xử lý sự kiện đăng ký
  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final session = await _authRepository.register(
        name: event.name,
        email: event.email,
        password: event.password,
      );
      emit(Authenticated(session));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  // Xử lý sự kiện đăng xuất
  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.logout();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final session = await _authRepository.restoreSession();
      if (session != null) {
        emit(Authenticated(session));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }
}
