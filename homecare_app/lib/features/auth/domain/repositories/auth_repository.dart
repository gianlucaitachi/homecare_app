// Đây là "hợp đồng" (abstract class) định nghĩa các chức năng
// mà lớp repository xác thực phải có.
import '../entities/auth_session.dart';

abstract class AuthRepository {
  // Hàm đăng nhập
  Future<AuthSession> login({required String email, required String password});

  // Hàm đăng ký
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  });

  // Hàm đăng xuất
  Future<void> logout();

  // Phục hồi phiên đăng nhập đã lưu
  Future<AuthSession?> restoreSession();
}
