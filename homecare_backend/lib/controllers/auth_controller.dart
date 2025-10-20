import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:crypto/crypto.dart';

import '../repositories/user_repository.dart';
import '../services/jwt_service.dart';

class AuthController {
  final UserRepository _userRepository;
  final JwtService _jwtService = JwtService();

  AuthController(this._userRepository);

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

    final passwordHash = sha256.convert(utf8.encode(password)).toString();

    await _userRepository.createUser(
      name: name,
      email: email,
      passwordHash: passwordHash,
    );

    return Response.ok(jsonEncode({'message': 'registration successful'}));
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
      return Response.forbidden(jsonEncode({'error': 'invalid_credentials'}));
    }

    final passwordHash = sha256.convert(utf8.encode(password)).toString();
    if (user.passwordHash != passwordHash) {
      return Response.forbidden(jsonEncode({'error': 'invalid_credentials'}));
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
      final sub = jwt.payload['sub'] as String?;

      if (sub == null || jwt.payload['type'] != 'refresh') {
        return Response.forbidden(jsonEncode({'error': 'invalid refresh token'}));
      }
      
      final accessToken = _jwtService.signAccessToken({'sub': sub});
      final newRefreshToken = _jwtService.signRefreshToken({'sub': sub, 'type': 'refresh'});
      
      // In a real app, you should implement token rotation and revocation logic here.
      
      return Response.ok(jsonEncode({'accessToken': accessToken, 'refreshToken': newRefreshToken}));
    } catch (e) {
      return Response.forbidden(jsonEncode({'error': 'invalid_token'}));
    }
  }

  Future<Response> logout(Request req) async {
    // In a real app, you would add logic here to invalidate the refresh token.
    return Response.ok(jsonEncode({'message': 'logged out successfully'}));
  }
}
