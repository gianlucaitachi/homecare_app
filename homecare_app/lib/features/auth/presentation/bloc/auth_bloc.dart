
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

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
  }

  // Xử lý sự kiện đăng nhập
  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.login(
        email: event.email,
        password: event.password,
      );
      emit(Authenticated());
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
      await _authRepository.register(
        name: event.name,
        email: event.email,
        password: event.password,
      );
      // Sau khi đăng ký thành công, có thể tự động đăng nhập hoặc
      // chuyển về màn hình đăng nhập với thông báo.
      // Ở đây, chúng ta sẽ chuyển sang trạng thái đã xác thực.
      emit(Authenticated());
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
}
