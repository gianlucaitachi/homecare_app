import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:homecare_backend/controllers/auth_controller.dart';
import 'package:homecare_backend/models/user_model.dart';
import 'package:homecare_backend/repositories/user_repository.dart';
import 'package:homecare_backend/services/jwt_service.dart';
import 'package:homecare_backend/services/password_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class InMemoryUserRepository implements UserRepository {
  final Map<String, User> _users = {};
  final Map<String, String> _families = {};

  @override
  Future<User?> findUserByEmail(String email) async {
    return _users[email];
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
    if (familyName != null) {
      _families[familyId] = familyName;
    }
    final user = User(
      id: id,
      name: name,
      email: email,
      passwordHash: passwordHash,
      familyId: familyId,
    );
    _users[email] = user;
    return user;
  }
}

void main() {
  group('AuthController', () {
    late InMemoryUserRepository userRepository;
    late PasswordService passwordService;
    late AuthController controller;
    late Router router;

    setUp(() {
      userRepository = InMemoryUserRepository();
      passwordService = const PasswordService();
      controller = AuthController(
        userRepository,
        jwtService: JwtService(
          accessSecret: 'access-secret',
          refreshSecret: 'refresh-secret',
          accessTokenDuration: const Duration(minutes: 15),
          refreshTokenDuration: const Duration(days: 1),
        ),
        passwordService: passwordService,
        uuid: const Uuid(),
      );
      router = Router()
        ..post('/api/auth/register', controller.register)
        ..post('/api/auth/login', controller.login);
    });

    test('register and login flow with bcrypt hashing', () async {
      final registerRequest = Request(
        'POST',
        Uri.parse('http://localhost/api/auth/register'),
        body: jsonEncode({
          'email': 'alice@example.com',
          'password': 'SuperSecret123!',
          'name': 'Alice',
        }),
        headers: {'content-type': 'application/json'},
      );

      final registerResponse = await router.call(registerRequest);
      expect(registerResponse.statusCode, equals(200));

      final registerBody =
          jsonDecode(await registerResponse.readAsString()) as Map<String, dynamic>;
      expect(registerBody['message'], equals('registration successful'));
      expect(registerBody['user']['email'], equals('alice@example.com'));
      expect(registerBody['user']['familyId'], isNotEmpty);
      expect(registerBody['accessToken'], isNotEmpty);
      expect(registerBody['refreshToken'], isNotEmpty);

      final storedUser = await userRepository.findUserByEmail('alice@example.com');
      expect(storedUser, isNotNull);
      expect(storedUser!.passwordHash, isNot(equals('SuperSecret123!')));
      expect(storedUser.familyId, equals(registerBody['user']['familyId']));
      expect(
        passwordService.verifyPassword('SuperSecret123!', storedUser.passwordHash),
        isTrue,
      );

      final loginRequest = Request(
        'POST',
        Uri.parse('http://localhost/api/auth/login'),
        body: jsonEncode({
          'email': 'alice@example.com',
          'password': 'SuperSecret123!',
        }),
        headers: {'content-type': 'application/json'},
      );

      final loginResponse = await router.call(loginRequest);
      expect(loginResponse.statusCode, equals(200));

      final loginBody =
          jsonDecode(await loginResponse.readAsString()) as Map<String, dynamic>;
      expect(loginBody['accessToken'], isNotEmpty);
      expect(loginBody['refreshToken'], isNotEmpty);
      expect(loginBody['user']['email'], equals('alice@example.com'));
      expect(loginBody['user']['familyId'], equals(storedUser.familyId));
    });

    test('login accepts legacy sha256 password hashes', () async {
      final legacyPassword = 'LegacySecret123!';
      final legacyHash = sha256.convert(utf8.encode(legacyPassword)).toString();

      await userRepository.createUser(
        id: const Uuid().v4(),
        name: 'Bob',
        email: 'bob@example.com',
        passwordHash: legacyHash,
        familyId: const Uuid().v4(),
      );

      final loginRequest = Request(
        'POST',
        Uri.parse('http://localhost/api/auth/login'),
        body: jsonEncode({
          'email': 'bob@example.com',
          'password': legacyPassword,
        }),
        headers: {'content-type': 'application/json'},
      );

      final response = await router.call(loginRequest);
      expect(response.statusCode, equals(200));

      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['accessToken'], isNotEmpty);
      expect(body['refreshToken'], isNotEmpty);
      expect(body['user']['email'], equals('bob@example.com'));
      expect(body['user']['familyId'], isNotEmpty);
    });
  });
}
