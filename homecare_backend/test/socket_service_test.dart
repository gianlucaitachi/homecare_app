import 'dart:async';
import 'dart:io';

import 'package:homecare_backend/models/message_model.dart';
import 'package:homecare_backend/repositories/message_repository.dart';
import 'package:homecare_backend/services/socket_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _FakeSocketRoom implements SocketRoom {
  _FakeSocketRoom(this.name);

  final String name;
  final List<Map<String, dynamic>> emittedEvents = [];

  @override
  void emit(String event, dynamic data) {
    emittedEvents.add({'event': event, 'data': data});
  }
}

class _FakeSocketClient implements SocketClient {
  final List<String> joinedRooms = [];
  final Map<String, FutureOr<void> Function(dynamic data)> handlers = {};

  @override
  void join(String room) {
    joinedRooms.add(room);
  }

  @override
  void on(String event, FutureOr<void> Function(dynamic data) handler) {
    handlers[event] = handler;
  }

  Future<void> emit(String event, dynamic payload) async {
    final handler = handlers[event];
    if (handler != null) {
      await handler(payload);
    }
  }
}

class _FakeSocketServer implements SocketServerAdapter {
  final Map<String, _FakeSocketRoom> rooms = {};
  void Function(SocketClient client)? _onConnection;

  @override
  void attach(HttpServer server) {}

  @override
  void onConnection(void Function(SocketClient client) handler) {
    _onConnection = handler;
  }

  void simulateConnection(_FakeSocketClient client) {
    _onConnection?.call(client);
  }

  @override
  SocketRoom toRoom(String room) {
    return rooms.putIfAbsent(room, () => _FakeSocketRoom(room));
  }
}

class _MockMessageRepository extends Mock implements MessageRepository {}

void main() {
  group('SocketService', () {
    late _FakeSocketServer fakeServer;
    late _MockMessageRepository repository;
    late SocketService service;

    setUp(() {
      fakeServer = _FakeSocketServer();
      repository = _MockMessageRepository();
      service = SocketService(server: fakeServer, messageRepository: repository);
      service.initialize();
    });

    test('joins room when joinRoom event is received', () async {
      final client = _FakeSocketClient();
      fakeServer.simulateConnection(client);

      await client.emit('joinRoom', {'familyId': 'family-123'});

      expect(client.joinedRooms, contains('family:family-123'));
    });

    test('persists chat message and broadcasts to room', () async {
      final client = _FakeSocketClient();
      fakeServer.simulateConnection(client);

      final message = Message(
        id: 'message-1',
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

      await client.emit('chat:send', {
        'familyId': 'family-1',
        'senderId': 'user-1',
        'content': 'Hello',
      });

      final room = fakeServer.rooms['family:family-1'];
      expect(room, isNotNull);
      expect(room!.emittedEvents.single['event'], equals('chat:message'));
      expect(room.emittedEvents.single['data'], equals(message.toJson()));
    });

    test('broadcastTaskUpdated emits payload to the correct room', () {
      service.broadcastTaskUpdated('family-55', {'taskId': 'task-9'});

      final room = fakeServer.rooms['family:family-55'];
      expect(room, isNotNull);
      expect(room!.emittedEvents.single['event'], equals('task:updated'));
      expect(room.emittedEvents.single['data'], equals({'taskId': 'task-9'}));
    });
  });
}
