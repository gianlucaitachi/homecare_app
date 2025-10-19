import '../db/postgres_client.dart';
import '../models/user_model.dart';

abstract class UserRepository {
  Future<User?> findUserByEmail(String email);

  Future<User> createUser({
    required String id,
    required String name,
    required String email,
    required String passwordHash,
  });
}

class PostgresUserRepository implements UserRepository {
  PostgresUserRepository(this._db);

  final PostgresClient _db;

  @override
  Future<User?> findUserByEmail(String email) async {
    final result = await _db.raw.query(
      'SELECT id, name, email, password_hash FROM users WHERE email = @email LIMIT 1',
      substitutionValues: {'email': email},
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first.toColumnMap();
    return User(
      id: row['id'] as String,
      name: row['name'] as String,
      email: row['email'] as String,
      passwordHash: row['password_hash'] as String,
    );
  }

  @override
  Future<User> createUser({
    required String id,
    required String name,
    required String email,
    required String passwordHash,
  }) async {
    await _db.raw.query(
      'INSERT INTO users (id, name, email, password_hash) VALUES (@id, @name, @email, @hash)',
      substitutionValues: {
        'id': id,
        'name': name,
        'email': email,
        'hash': passwordHash,
      },
    );

    return User(
      id: id,
      name: name,
      email: email,
      passwordHash: passwordHash,
    );
  }
}
