import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtService {
  JwtService({
    String? accessSecret,
    String? refreshSecret,
    Duration accessTokenDuration = const Duration(hours: 1),
    Duration refreshTokenDuration = const Duration(days: 7),
  })  : _accessSecret = accessSecret ??
            Platform.environment['JWT_ACCESS_SECRET'] ??
            'access-secret',
        _refreshSecret = refreshSecret ??
            Platform.environment['JWT_REFRESH_SECRET'] ??
            'refresh-secret',
        _accessTokenDuration = accessTokenDuration,
        _refreshTokenDuration = refreshTokenDuration;

  final String _accessSecret;
  final String _refreshSecret;
  final Duration _accessTokenDuration;
  final Duration _refreshTokenDuration;

  String signAccessToken(Map<String, dynamic> payload) {
    final jwt = JWT(payload);
    return jwt.sign(SecretKey(_accessSecret), expiresIn: _accessTokenDuration);
  }

  String signRefreshToken(Map<String, dynamic> payload) {
    final jwt = JWT(payload);
    return jwt.sign(SecretKey(_refreshSecret), expiresIn: _refreshTokenDuration);
  }

  JWT verifyAccessToken(String token) {
    return JWT.verify(token, SecretKey(_accessSecret));
  }

  JWT verifyRefreshToken(String token) {
    return JWT.verify(token, SecretKey(_refreshSecret));
  }
}
