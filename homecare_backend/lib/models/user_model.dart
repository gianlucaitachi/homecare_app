class User {
  final String id;
  final String name;
  final String email;
  final String passwordHash;

  User({
    required this.id,
    required this.name,
  required this.email,
    required this.passwordHash,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
  };
}
