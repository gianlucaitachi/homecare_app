import 'package:shelf/shelf.dart';

import '../services/jwt_service.dart';
import '../utils/request_context.dart';

Middleware authenticationMiddleware(JwtService jwtService) {
  return (innerHandler) {
    return (request) async {
      final authHeader = request.headers['Authorization'] ??
          request.headers['authorization'];

      String? token;
      if (authHeader != null) {
        final parts = authHeader.split(' ');
        if (parts.length == 2 && parts.first.toLowerCase() == 'bearer') {
          token = parts.last.trim();
        }
      }

      if (token != null && token.isNotEmpty) {
        try {
          final jwt = jwtService.verifyAccessToken(token);
          final subject = jwt.payload['sub'];
          if (subject is String && subject.isNotEmpty) {
            final updatedRequest =
                attachAuthenticatedUser(request, subject);
            return innerHandler(updatedRequest);
          }
        } catch (_) {
          // Ignore and allow the handler to decide how to respond.
        }
      }

      return innerHandler(request);
    };
  };
}
