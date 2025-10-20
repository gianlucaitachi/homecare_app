import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JwtService {
  JwtService({
    Duration? accessTokenExpiry,
    Duration? refreshTokenExpiry,
  })  : _accessSecret =
            Platform.environment['JWT_ACCESS_SECRET'] ?? 'dev_access_secret',
        _refreshSecret =
            Platform.environment['JWT_REFRESH_SECRET'] ?? 'dev_refresh_secret',
        accessTokenExpiry = accessTokenExpiry ?? const Duration(minutes: 15),
        refreshTokenExpiry = refreshTokenExpiry ?? const Duration(days: 7);

  final String _accessSecret;
  final String _refreshSecret;
  final Duration accessTokenExpiry;
  final Duration refreshTokenExpiry;

  String signAccessToken(Map<String, dynamic> payload) {
    final jwt = JWT(payload);
    return jwt.sign(
      SecretKey(_accessSecret),
      expiresIn: accessTokenExpiry,
    );
  }

  String signRefreshToken(Map<String, dynamic> payload) {
    final jwt = JWT(payload);
    return jwt.sign(
      SecretKey(_refreshSecret),
      expiresIn: refreshTokenExpiry,
    );
  }

  JWT verifyAccessToken(String token) {
    return JWT.verify(token, SecretKey(_accessSecret));
  }

  JWT verifyRefreshToken(String token) {
    return JWT.verify(token, SecretKey(_refreshSecret));
  }

  JWT verify(String token) {
    try {
      return verifyAccessToken(token);
    } on JWTExpiredError {
      rethrow;
    } on JWTError {
      return verifyRefreshToken(token);
    }
  }
}
