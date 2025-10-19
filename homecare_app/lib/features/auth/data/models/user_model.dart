import '../../domain/entities/user.dart';

/// Lớp Model đại diện cho người dùng trong tầng Data.
/// Nó kế thừa từ User Entity và thêm vào logic để phân tích cú pháp JSON.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
  });

  /// Factory constructor để tạo một UserModel từ một Map (JSON).
  /// API của chúng ta trả về một object 'user' chứa thông tin này.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
    );
  }
}
