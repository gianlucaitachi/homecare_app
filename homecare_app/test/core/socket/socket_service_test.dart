import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/core/socket/socket_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _FakeSocketClient implements SocketClient {
  final Map<String, EventHandler> _handlers = {};
  final List<Map<String, dynamic>> emittedEvents = [];
  bool _connected = false;
  bool _disposed = false;

  @override
  void on(String event, EventHandler handler) {
    _handlers[event] = handler;
  }

  @override
  void emit(String event, dynamic data) {
    emittedEvents.add({'event': event, 'data': data});
  }

  @override
  void connect() {
    _connected = true;
    unawaited(_handlers['connect']?.call(null));
  }

  @override
  void disconnect() {
    _connected = false;
    unawaited(_handlers['disconnect']?.call(null));
  }

  @override
  void dispose() {
    _disposed = true;
  }

  @override
  bool get connected => _connected;

  bool get disposed => _disposed;

  Future<void> trigger(String event, dynamic payload) async {
    final handler = _handlers[event];
    if (handler != null) {
      await handler(payload);
    }
  }
}

void main() {
  test('SocketIoClientWrapper tear-off returns SocketClient implementation', () {
    final factory = SocketIoClientWrapper.new;
    final socket = factory('http://localhost', {'autoConnect': false});

    expect(socket, isA<SocketClient>());
    expect(socket, isA<SocketIoClientWrapper>());

    socket.dispose();
  });

  group('SocketService', () {
    late _MockSecureStorage secureStorage;
    late _FakeSocketClient fakeSocket;
    late SocketService service;

    setUp(() {
      secureStorage = _MockSecureStorage();
      fakeSocket = _FakeSocketClient();
      when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer((_) async => 'token');
      service = SocketService(
        secureStorage,
        socketFactory: (uri, options) => fakeSocket,
      );
    });

    test('connect uses provided factory and attaches listeners', () async {
      await service.connect('http://localhost:8080');
      expect(fakeSocket.connected, isTrue);
    });

    test('joinRoom emits join event with family id', () async {
      await service.connect('http://localhost:8080');
      service.joinRoom('family-9');

      expect(fakeSocket.emittedEvents.last, {
        'event': 'joinRoom',
        'data': {'familyId': 'family-9'},
      });
    });

    test('sendChatMessage emits chat payload', () async {
      await service.connect('http://localhost:8080');
      service.sendChatMessage(familyId: 'family-1', senderId: 'user-2', content: 'Hello');

      expect(fakeSocket.emittedEvents.last, {
        'event': 'chat:send',
        'data': {'familyId': 'family-1', 'senderId': 'user-2', 'content': 'Hello'},
      });
    });

    test('chatMessages stream emits incoming chat payloads', () async {
      await service.connect('http://localhost:8080');
      final future = service.chatMessages.first;

      await fakeSocket.trigger('chat:message', {
        'id': '1',
        'familyId': 'family-1',
        'senderId': 'user-2',
        'content': 'Hi',
        'createdAt': DateTime.now().toIso8601String(),
      });

      final event = await future;
      expect(event['content'], equals('Hi'));
    });

    test('taskUpdates stream emits incoming task payloads', () async {
      await service.connect('http://localhost:8080');
      final future = service.taskUpdates.first;

      await fakeSocket.trigger('task:updated', {'taskId': 'task-1'});

      final event = await future;
      expect(event['taskId'], equals('task-1'));
    });
  });
}
