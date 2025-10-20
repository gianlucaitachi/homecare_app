import 'dart:convert';

import 'package:homecare_backend/controllers/chat_controller.dart';
import 'package:homecare_backend/models/message_model.dart';
import 'package:homecare_backend/repositories/message_repository.dart';
import 'package:homecare_backend/services/socket_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _MockMessageRepository extends Mock implements MessageRepository {}

class _MockSocketService extends Mock implements SocketService {}

void main() {
  group('ChatController', () {
    late _MockMessageRepository repository;
    late _MockSocketService socketService;
    late ChatController controller;

    setUp(() {
      repository = _MockMessageRepository();
      socketService = _MockSocketService();
      controller = ChatController(repository, socketService);
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

      final response = await controller.getMessages(Request('GET', Uri()), 'family-1');
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

      final request = Request(
        'POST',
        Uri.parse('http://localhost/families/family-1/messages'),
        body: jsonEncode({'senderId': 'user-1', 'content': 'Hello'}),
      );

      final response = await controller.postMessage(request, 'family-1');

      expect(response.statusCode, equals(201));
      verify(() => socketService.broadcastChatMessage(message)).called(1);
    });
  });
}
