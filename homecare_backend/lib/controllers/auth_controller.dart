import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import '../repositories/user_repository.dart';
import '../services/jwt_service.dart';
import '../services/password_service.dart';
import '../utils/request_context.dart';

class AuthController {
  AuthController(
    this._userRepository, {
    JwtService? jwtService,
    PasswordService? passwordService,
    Uuid? uuid,
  })  : _jwtService = jwtService ?? JwtService(),
        _passwordService = passwordService ?? const PasswordService(),
        _uuid = uuid ?? const Uuid();

  final UserRepository _userRepository;
  final JwtService _jwtService;
  final PasswordService _passwordService;
  final Uuid _uuid;

  Future<Response> register(Request req) async {
    final body = jsonDecode(await req.readAsString());
    final email = body['email'] as String?;
    final password = body['password'] as String?;
    final name = body['name'] as String?;

    if (email == null || password == null || name == null) {
      return Response(400, body: jsonEncode({'error': 'email, password, and name are required'}));
    }

    final existingUser = await _userRepository.findUserByEmail(email);
    if (existingUser != null) {
      return Response(409, body: jsonEncode({'error': 'user with this email already exists'}));
    }

    final passwordHash = _passwordService.hashPassword(password);
    final userId = _uuid.v4();
    final familyId = _uuid.v4();

    final user = await _userRepository.createUser(
      id: userId,
      name: name,
      email: email,
      passwordHash: passwordHash,
      familyId: familyId,
      familyName: "${name}'s Family",
    );

    final accessToken = _jwtService.signAccessToken({'sub': user.id});
    final refreshToken =
        _jwtService.signRefreshToken({'sub': user.id, 'type': 'refresh'});

    return Response.ok(
      jsonEncode(
        {
          'message': 'registration successful',
          'user': user.toJson(),
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        },
      ),
    );
  }

  Future<Response> login(Request req) async {
    final body = jsonDecode(await req.readAsString());
    final email = body['email'] as String?;
    final password = body['password'] as String?;

    if (email == null || password == null) {
      return Response(400, body: jsonEncode({'error': 'email and password are required'}));
    }

    final user = await _userRepository.findUserByEmail(email);
    if (user == null) {
      return Response(401, body: jsonEncode({'error': 'invalid_credentials'}));
    }

    final isValidPassword =
        _passwordService.verifyPassword(password, user.passwordHash);
    if (!isValidPassword) {
      return Response(401, body: jsonEncode({'error': 'invalid_credentials'}));
    }

    final accessToken = _jwtService.signAccessToken({'sub': user.id});
    final refreshToken = _jwtService.signRefreshToken({'sub': user.id, 'type': 'refresh'});

    return Response.ok(jsonEncode({
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    }));
  }

  Future<Response> refresh(Request req) async {
    final body = jsonDecode(await req.readAsString());
    final refreshToken = body['refreshToken'] as String?;
    if (refreshToken == null) return Response(400, body: jsonEncode({'error': 'refreshToken is required'}));

    try {
      final jwt = _jwtService.verifyRefreshToken(refreshToken);
      final sub = jwt.payload['sub'];
      final type = jwt.payload['type'];

      if (sub is! String || sub.isEmpty || type != 'refresh') {
        return Response(401, body: jsonEncode({'error': 'invalid_token'}));
      }

      final authenticatedUserId = req.authenticatedUserId;
      if (authenticatedUserId != null && authenticatedUserId != sub) {
        return Response(401, body: jsonEncode({'error': 'invalid_token'}));
      }

      final userId = authenticatedUserId ?? sub;

      if (authenticatedUserId == null) {
        final user = await _userRepository.findUserById(userId);
        if (user == null) {
          return Response(401, body: jsonEncode({'error': 'invalid_token'}));
        }
      }

      final accessToken = _jwtService.signAccessToken({'sub': userId});
      final newRefreshToken =
          _jwtService.signRefreshToken({'sub': userId, 'type': 'refresh'});

      // In a real app, you should implement token rotation and revocation logic here.

      return Response.ok(jsonEncode({'accessToken': accessToken, 'refreshToken': newRefreshToken}));
    } catch (e) {
      return Response(401, body: jsonEncode({'error': 'invalid_token'}));
    }
  }

  Future<Response> logout(Request req) async {
    if (req.authenticatedUserId == null) {
      return _unauthorizedResponse();
    }
    // In a real app, you would add logic here to invalidate the refresh token.
    return Response.ok(jsonEncode({'message': 'logged out successfully'}));
  }

  Response _unauthorizedResponse() {
    return Response(401, body: jsonEncode({'error': 'unauthorized'}));
  }
}
