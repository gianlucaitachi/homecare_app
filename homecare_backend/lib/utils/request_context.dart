import 'package:shelf/shelf.dart';

const String kAuthenticatedUserIdContextKey = 'authenticatedUserId';

extension AuthenticatedRequest on Request {
  String? get authenticatedUserId {
    final value = context[kAuthenticatedUserIdContextKey];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }
}

Request attachAuthenticatedUser(Request request, String userId) {
  final updatedContext = Map<String, Object?>.from(request.context);
  updatedContext[kAuthenticatedUserIdContextKey] = userId;
  return request.change(context: updatedContext);
}
