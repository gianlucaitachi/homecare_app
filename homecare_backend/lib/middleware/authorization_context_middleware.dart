import 'package:shelf/shelf.dart';

import '../models/auth_context.dart';
import '../repositories/user_repository.dart';
import '../utils/request_context.dart';

Middleware authorizationContextMiddleware(UserRepository userRepository) {
  return (innerHandler) {
    return (request) async {
      final subject = request.authenticatedUserId;
      if (subject != null && subject.isNotEmpty) {
        final user = await userRepository.findUserById(subject);
        if (user != null) {
          final updatedContext = Map<String, Object?>.from(request.context);
          updatedContext['auth'] =
              AuthContext(userId: user.id, familyId: user.familyId);
          final updatedRequest = request.change(context: updatedContext);
          return innerHandler(updatedRequest);
        }
      }

      return innerHandler(request);
    };
  };
}
