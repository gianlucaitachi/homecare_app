import 'package:equatable/equatable.dart';

class Member extends Equatable {
  const Member({
    required this.id,
    required this.familyId,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;
  final String familyId;
  final String name;
  final String email;
  final String role;

  String get roleLabel {
    final normalized = role.trim().replaceAll('_', ' ');
    if (normalized.isEmpty) {
      return 'Member';
    }
    return normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) =>
            part.substring(0, 1).toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  List<Object?> get props => [id, familyId, name, email, role];
}
