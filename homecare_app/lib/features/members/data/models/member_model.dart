import '../../domain/entities/member.dart';

class MemberModel extends Member {
  const MemberModel({
    required super.id,
    required super.familyId,
    required super.name,
    required super.email,
    required super.role,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      id: json['id'] as String,
      familyId: (json['familyId'] ?? json['family_id'] ?? '') as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
    );
  }

  static List<MemberModel> fromJsonList(List<dynamic> data) {
    return data
        .whereType<Map<String, dynamic>>()
        .map(MemberModel.fromJson)
        .toList();
  }
}
