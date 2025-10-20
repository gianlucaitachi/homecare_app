import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:homecare_backend/controllers/auth_controller.dart';
import 'package:homecare_backend/middleware/authentication_middleware.dart';
import 'package:homecare_backend/models/user_model.dart';
import 'package:homecare_backend/repositories/user_repository.dart';
import 'package:homecare_backend/services/jwt_service.dart';
import 'package:homecare_backend/services/password_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class InMemoryUserRepository implements UserRepository {
  final Map<String, User> _usersByEmail = {};
  final Map<String, User> _usersById = {};
  final Map<String, String> _families = {};

  @override
  Future<User?> findUserByEmail(String email) async {
    return _usersByEmail[email];
  }

  @override
  Future<User?> findUserById(String id) async {
    return _usersById[id];
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
    _usersByEmail[email] = user;
    _usersById[id] = user;
    return user;
  }
}

void main() {
  group('AuthController', () {
    late InMemoryUserRepository userRepository;
    late PasswordService passwordService;
    late AuthController controller;
    late Router router;
    late JwtService jwtService;
    late Handler refreshHandler;
    late Handler logoutHandler;

    setUp(() {
      userRepository = InMemoryUserRepository();
      passwordService = const PasswordService();
      jwtService = JwtService(
        accessSecret: 'access-secret',
        refreshSecret: 'refresh-secret',
        accessTokenDuration: const Duration(minutes: 15),
        refreshTokenDuration: const Duration(days: 1),
      );
      controller = AuthController(
        userRepository,
        jwtService: jwtService,
        passwordService: passwordService,
        uuid: const Uuid(),
      );
      router = Router()
        ..post('/api/auth/register', controller.register)
        ..post('/api/auth/login', controller.login);
      refreshHandler = Pipeline()
          .addMiddleware(authenticationMiddleware(jwtService))
          .addHandler(controller.refresh);
      logoutHandler = Pipeline()
          .addMiddleware(authenticationMiddleware(jwtService))
          .addHandler(controller.logout);
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

    test('refresh issues new tokens with valid refresh token', () async {
      final registerResponse = await router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/api/auth/register'),
          body: jsonEncode({
            'email': 'dave@example.com',
            'password': 'DavePassword123',
            'name': 'Dave',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );

      final registerBody =
          jsonDecode(await registerResponse.readAsString()) as Map<String, dynamic>;
      final refreshToken = registerBody['refreshToken'] as String;

      final response = await refreshHandler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/auth/refresh'),
          body: jsonEncode({'refreshToken': refreshToken}),
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['accessToken'], isNotEmpty);
      expect(body['refreshToken'], isNotEmpty);
      expect(body['refreshToken'], isNot(equals(refreshToken)));
    });

    test('refresh succeeds with an expired access token', () async {
      jwtService = JwtService(
        accessSecret: 'access-secret',
        refreshSecret: 'refresh-secret',
        accessTokenDuration: const Duration(milliseconds: 5),
        refreshTokenDuration: const Duration(days: 1),
      );
      controller = AuthController(
        userRepository,
        jwtService: jwtService,
        passwordService: passwordService,
        uuid: const Uuid(),
      );
      router = Router()
        ..post('/api/auth/register', controller.register)
        ..post('/api/auth/login', controller.login);
      refreshHandler = Pipeline()
          .addMiddleware(authenticationMiddleware(jwtService))
          .addHandler(controller.refresh);

      final registerResponse = await router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/api/auth/register'),
          body: jsonEncode({
            'email': 'expired@example.com',
            'password': 'ExpiredPassword123',
            'name': 'Expired User',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );

      final registerBody =
          jsonDecode(await registerResponse.readAsString()) as Map<String, dynamic>;
      final accessToken = registerBody['accessToken'] as String;
      final refreshToken = registerBody['refreshToken'] as String;

      await Future.delayed(const Duration(milliseconds: 20));

      final response = await refreshHandler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/auth/refresh'),
          body: jsonEncode({'refreshToken': refreshToken}),
          headers: {
            'content-type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        ),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['accessToken'], isNotEmpty);
      expect(body['refreshToken'], isNotEmpty);
    });

    test('refresh rejects refresh tokens for unknown users', () async {
      final refreshToken = jwtService
          .signRefreshToken({'sub': const Uuid().v4(), 'type': 'refresh'});

      final response = await refreshHandler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/auth/refresh'),
          body: jsonEncode({'refreshToken': refreshToken}),
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(response.statusCode, equals(401));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], equals('invalid_token'));
    });

    test('refresh rejects refresh tokens with incorrect type', () async {
      final registerResponse = await router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/api/auth/register'),
          body: jsonEncode({
            'email': 'type-check@example.com',
            'password': 'TypeCheckPassword123',
            'name': 'Type Check',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );

      final registerBody =
          jsonDecode(await registerResponse.readAsString()) as Map<String, dynamic>;
      final userId = registerBody['user']['id'] as String;

      final invalidRefreshToken = jwtService
          .signRefreshToken({'sub': userId, 'type': 'session'});

      final response = await refreshHandler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/auth/refresh'),
          body: jsonEncode({'refreshToken': invalidRefreshToken}),
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(response.statusCode, equals(401));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], equals('invalid_token'));
    });

    test('logout requires authentication', () async {
      final registerResponse = await router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/api/auth/register'),
          body: jsonEncode({
            'email': 'frank@example.com',
            'password': 'FrankPassword123',
            'name': 'Frank',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );

      final registerBody =
          jsonDecode(await registerResponse.readAsString()) as Map<String, dynamic>;
      final accessToken = registerBody['accessToken'] as String;

      final unauthorizedResponse = await logoutHandler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/auth/logout'),
        ),
      );

      expect(unauthorizedResponse.statusCode, equals(401));

      final authorizedResponse = await logoutHandler(
        Request(
          'POST',
          Uri.parse('http://localhost/api/auth/logout'),
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      expect(authorizedResponse.statusCode, equals(200));
      final body = jsonDecode(await authorizedResponse.readAsString())
          as Map<String, dynamic>;
      expect(body['message'], equals('logged out successfully'));
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

    test('login returns 401 for unknown user', () async {
      final loginRequest = Request(
        'POST',
        Uri.parse('http://localhost/auth/login'),
        body: jsonEncode({
          'email': 'unknown@example.com',
          'password': 'does-not-matter',
        }),
        headers: {'content-type': 'application/json'},
      );

      final response = await controller.login(loginRequest);
      expect(response.statusCode, equals(401));

      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body, equals({'error': 'invalid_credentials'}));
    });

    test('login returns 401 for incorrect password', () async {
      await controller.register(
        Request(
          'POST',
          Uri.parse('http://localhost/auth/register'),
          body: jsonEncode({
            'email': 'carol@example.com',
            'password': 'CorrectHorseBatteryStaple',
            'name': 'Carol',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );

      final loginRequest = Request(
        'POST',
        Uri.parse('http://localhost/auth/login'),
        body: jsonEncode({
          'email': 'carol@example.com',
          'password': 'wrong-password',
        }),
        headers: {'content-type': 'application/json'},
      );

      final response = await controller.login(loginRequest);
      expect(response.statusCode, equals(401));

      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body, equals({'error': 'invalid_credentials'}));
    });
  });
}
