import '../db/postgres_client.dart';
import '../models/user_model.dart';

abstract class UserRepository {
  Future<User?> findUserByEmail(String email);

  Future<User?> findUserById(String id);

  Future<User> createUser({
    required String id,
    required String name,
    required String email,
    required String passwordHash,
    required String familyId,
    String? familyName,
  });
}

class PostgresUserRepository implements UserRepository {
  PostgresUserRepository(this._db);

  final PostgresClient _db;

  @override
  Future<User?> findUserByEmail(String email) => _findUserBy(
        column: 'email',
        value: email,
      );

  @override
  Future<User?> findUserById(String id) => _findUserBy(
        column: 'id',
        value: id,
      );

  Future<User?> _findUserBy({required String column, required Object value}) async {
    final result = await _db.raw.query(
      'SELECT id, name, email, password_hash, family_id FROM users WHERE $column = @value LIMIT 1',
      substitutionValues: {'value': value},
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
      familyId: row['family_id'] as String,
    );
  }

  @override
  Future<User> createUser({
    required String id,
    required String name,
    required String email,
    required String passwordHash,
    required String familyId,
    String? familyName,
  }) async {
    await _db.raw.transaction((ctx) async {
      if (familyName != null) {
        await ctx.query(
          'INSERT INTO families (id, name) VALUES (@familyId, @familyName) ON CONFLICT (id) DO NOTHING',
          substitutionValues: {
            'familyId': familyId,
            'familyName': familyName,
          },
        );
      }

      await ctx.query(
        'INSERT INTO users (id, name, email, password_hash, family_id) VALUES (@id, @name, @email, @hash, @familyId)',
        substitutionValues: {
          'id': id,
          'name': name,
          'email': email,
          'hash': passwordHash,
          'familyId': familyId,
        },
      );
    });

    return User(
      id: id,
      name: name,
      email: email,
      passwordHash: passwordHash,
      familyId: familyId,
    );
  }

}
