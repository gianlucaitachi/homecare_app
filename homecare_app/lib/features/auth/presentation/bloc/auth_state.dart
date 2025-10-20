
part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

// Trạng thái ban đầu, khi chưa có hành động gì
class AuthInitial extends AuthState {}

// Trạng thái đang xử lý (ví dụ: đang gọi API đăng nhập)
class AuthLoading extends AuthState {}

// Trạng thái xác thực thành công
// Đây chính là trạng thái thay thế cho 'AuthSuccess' mà code của bạn đang báo lỗi.
class Authenticated extends AuthState {
  const Authenticated(this.session);

  final AuthSession session;

  @override
  List<Object> get props => [session];
}

// Trạng thái chưa xác thực (ví dụ: sau khi đăng xuất hoặc lần đầu mở app)
class Unauthenticated extends AuthState {}

// Trạng thái khi có lỗi xảy ra
class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object> get props => [message];
}
