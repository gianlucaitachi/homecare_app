class User {
  final String id;
  final String name;
  final String email;
  final String passwordHash;
  final String familyId;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.familyId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'familyId': familyId,
  };
}
