import 'dart:convert';

import 'package:homecare_backend/controllers/auth_controller.dart';
import 'package:homecare_backend/models/user_model.dart';
import 'package:homecare_backend/repositories/user_repository.dart';
import 'package:homecare_backend/services/jwt_service.dart';
import 'package:homecare_backend/services/password_service.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class InMemoryUserRepository implements UserRepository {
  final Map<String, User> _users = {};

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
  }) async {
    final user = User(
      id: id,
      name: name,
      email: email,
      passwordHash: passwordHash,
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
    });

    test('register and login flow with bcrypt hashing', () async {
      final registerRequest = Request(
        'POST',
        Uri.parse('http://localhost/auth/register'),
        body: jsonEncode({
          'email': 'alice@example.com',
          'password': 'SuperSecret123!',
          'name': 'Alice',
        }),
        headers: {'content-type': 'application/json'},
      );

      final registerResponse = await controller.register(registerRequest);
      expect(registerResponse.statusCode, equals(200));

      final registerBody =
          jsonDecode(await registerResponse.readAsString()) as Map<String, dynamic>;
      expect(registerBody['message'], equals('registration successful'));
      expect(registerBody['user']['email'], equals('alice@example.com'));

      final storedUser = await userRepository.findUserByEmail('alice@example.com');
      expect(storedUser, isNotNull);
      expect(storedUser!.passwordHash, isNot(equals('SuperSecret123!')));
      expect(
        passwordService.verifyPassword('SuperSecret123!', storedUser.passwordHash),
        isTrue,
      );

      final loginRequest = Request(
        'POST',
        Uri.parse('http://localhost/auth/login'),
        body: jsonEncode({
          'email': 'alice@example.com',
          'password': 'SuperSecret123!',
        }),
        headers: {'content-type': 'application/json'},
      );

      final loginResponse = await controller.login(loginRequest);
      expect(loginResponse.statusCode, equals(200));

      final loginBody =
          jsonDecode(await loginResponse.readAsString()) as Map<String, dynamic>;
      expect(loginBody['accessToken'], isNotEmpty);
      expect(loginBody['refreshToken'], isNotEmpty);
      expect(loginBody['user']['email'], equals('alice@example.com'));
    });
  });
}
