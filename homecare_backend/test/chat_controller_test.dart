import 'dart:convert';

import 'package:homecare_backend/controllers/chat_controller.dart';
import 'package:homecare_backend/middleware/authentication_middleware.dart';
import 'package:homecare_backend/models/message_model.dart';
import 'package:homecare_backend/repositories/message_repository.dart';
import 'package:homecare_backend/services/jwt_service.dart';
import 'package:homecare_backend/services/socket_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

class _MockMessageRepository extends Mock implements MessageRepository {}

class _MockSocketService extends Mock implements SocketService {}

void main() {
  group('ChatController', () {
    late _MockMessageRepository repository;
    late _MockSocketService socketService;
    late ChatController controller;
    late Router router;
    late Handler handler;
    late JwtService jwtService;
    late String accessToken;

    setUp(() {
      repository = _MockMessageRepository();
      socketService = _MockSocketService();
      controller = ChatController(repository, socketService);
      router = Router()
        ..get('/api/families/<familyId>/messages', controller.getMessages)
        ..post('/api/families/<familyId>/messages', controller.postMessage);
      jwtService = JwtService(
        accessSecret: 'test-access',
        refreshSecret: 'test-refresh',
      );
      accessToken = jwtService.signAccessToken({'sub': 'user-42'});
      handler = Pipeline()
          .addMiddleware(authenticationMiddleware(jwtService))
          .addHandler(router.call);
    });

    Request _authedRequest(
      String method,
      String path, {
      Map<String, String>? headers,
      Object? body,
    }) {
      final updatedHeaders = <String, String>{
        'Authorization': 'Bearer $accessToken',
        ...?headers,
      };

      return Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: updatedHeaders,
        body: body,
      );
    }

    test('returns 401 when Authorization header is missing', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/families/family-1/messages'),
      );

      final response = await handler(request);

      expect(response.statusCode, equals(401));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], equals('unauthorized'));
    });

    test('returns 401 when Authorization token is invalid', () async {
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/families/family-1/messages'),
        headers: {'Authorization': 'Bearer invalid-token'},
      );

      final response = await handler(request);

      expect(response.statusCode, equals(401));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], equals('unauthorized'));
    });

    test('getMessages returns persisted messages', () async {
      when(() => repository.getMessagesByFamily('family-1')).thenAnswer((_) async => [
            Message(
              id: '1',
              familyId: 'family-1',
              senderId: 'user-1',
              content: 'Hi',
              createdAt: DateTime.parse('2024-01-01T10:00:00Z'),
            ),
          ]);
      final request = _authedRequest(
        'GET',
        '/api/families/family-1/messages',
      );

      final response = await handler(request);
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;

      expect(response.statusCode, equals(200));
      expect(body['messages'], isA<List>());
      expect((body['messages'] as List).single['content'], equals('Hi'));
    });

    test('postMessage persists message and broadcasts it', () async {
      final message = Message(
        id: '1',
        familyId: 'family-1',
        senderId: 'user-1',
        content: 'Hello',
        createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
      );

      when(() => repository.createMessage(
            familyId: 'family-1',
            senderId: 'user-1',
            content: 'Hello',
          )).thenAnswer((_) async => message);

      when(() => socketService.broadcastChatMessage(message)).thenReturn(null);

      final request = _authedRequest(
        'POST',
        '/api/families/family-1/messages',
        body: jsonEncode({'content': 'Hello'}),
        headers: {'content-type': 'application/json'},
      );

      final response = await handler(request);

      expect(response.statusCode, equals(201));
      verify(() => socketService.broadcastChatMessage(message)).called(1);
      verify(() => repository.createMessage(
            familyId: 'family-1',
            senderId: 'user-42',
            content: 'Hello',
          )).called(1);
    });
  });
}
