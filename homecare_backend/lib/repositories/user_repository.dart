import '../db/postgres_client.dart';
import '../models/user_model.dart';

class UserRepository {
  final PostgresClient _db;

  UserRepository(this._db);

  Future<User?> findUserByEmail(String email) async {
    final result = await _db.raw.query(
      'SELECT id, name, email, password_hash FROM users WHERE email = @email LIMIT 1',
      substitutionValues: {'email': email},
    );

    if (result.isEmpty) {
      return null;
    }

    // Chuyển kết quả truy vấn thành một Map để dễ truy cập
    final row = result.first.toColumnMap();
    return User(
      id: row['id'] as String,
      name: row['name'] as String,
      email: row['email'] as String,
      passwordHash: row['password_hash'] as String,
    );
  }

  Future<void> createUser({
    required String name,
    required String email,
    required String passwordHash,
  }) async {
    await _db.raw.query(
      'INSERT INTO users (name, email, password_hash) VALUES (@name, @email, @hash)',
      substitutionValues: {
        'name': name,
        'email': email,
        'hash': passwordHash,
      },
    );
  }
}
