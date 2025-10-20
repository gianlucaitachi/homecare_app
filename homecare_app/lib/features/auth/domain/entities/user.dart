import 'package:equatable/equatable.dart';

/// Lớp Entity đại diện cho đối tượng người dùng trong tầng Domain.
/// Nó không chứa logic phân tích cú pháp JSON hoặc bất kỳ sự phụ thuộc nào từ tầng Data.
class User extends Equatable {
  final String id;
  final String name;
  final String email;
  final String familyId;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.familyId,
  });

  @override
  List<Object?> get props => [id, name, email, familyId];
}
