
// Đây là "hợp đồng" (abstract class) định nghĩa các chức năng
// mà lớp repository xác thực phải có.
abstract class AuthRepository {
  // Hàm đăng nhập
  Future<void> login({required String email, required String password});

  // Hàm đăng ký
  Future<void> register({
    required String name,
    required String email,
    required String password,
  });

  // Hàm đăng xuất
  Future<void> logout();
}
