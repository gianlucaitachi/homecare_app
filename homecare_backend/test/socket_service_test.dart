import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:homecare_backend/models/message_model.dart';
import 'package:homecare_backend/repositories/message_repository.dart';
import 'package:homecare_backend/services/socket_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

class _FakeWebSocketSink implements WebSocketSink {
  final List<dynamic> sentMessages = [];
  final Completer<void> _doneCompleter = Completer<void>();

  @override
  void add(dynamic data) {
    sentMessages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> close([int? code, String? reason]) {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    return _doneCompleter.future;
  }

  @override
  Future<void> get done => _doneCompleter.future;
}

class _FakeWebSocketChannel extends WebSocketChannel {
  _FakeWebSocketChannel() : _controller = StreamController<dynamic>();

  final StreamController<dynamic> _controller;
  final _FakeWebSocketSink _sink = _FakeWebSocketSink();

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  WebSocketSink get sink => _sink;

  void addIncoming(dynamic data) {
    _controller.add(data);
  }

  Future<void> close() async {
    await _controller.close();
    await _sink.close();
  }

  List<dynamic> get sentMessages => _sink.sentMessages;
}

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

    test('broadcastChatMessage sends payload to registered web socket clients',
        () async {
      final channel = _FakeWebSocketChannel();
      service.registerWebSocketClient(
        familyId: 'family-1',
        userId: 'user-1',
        channel: channel,
      );

      final message = Message(
        id: 'message-1',
        familyId: 'family-1',
        senderId: 'user-2',
        content: 'Hello there',
        createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
      );

      service.broadcastChatMessage(message);

      expect(channel.sentMessages, isNotEmpty);
      final encoded = channel.sentMessages.single as String;
      final payload = jsonDecode(encoded) as Map<String, dynamic>;
      expect(payload['type'], equals('chat:message'));
      expect(payload['familyId'], equals('family-1'));
      expect(payload['data'], equals(message.toJson()));

      await channel.close();
    });

    test('broadcastTaskUpdated only emits to matching web socket family', () async {
      final matchingChannel = _FakeWebSocketChannel();
      final otherChannel = _FakeWebSocketChannel();
      service.registerWebSocketClient(
        familyId: 'family-1',
        userId: 'user-1',
        channel: matchingChannel,
      );
      service.registerWebSocketClient(
        familyId: 'family-2',
        userId: 'user-2',
        channel: otherChannel,
      );

      service.broadcastTaskUpdated('family-1', {'taskId': 'task-1'});

      expect(matchingChannel.sentMessages.length, equals(1));
      final payload =
          jsonDecode(matchingChannel.sentMessages.single as String) as Map<String, dynamic>;
      expect(payload['type'], equals('task:updated'));
      expect(payload['familyId'], equals('family-1'));
      expect(payload['data'], equals({'taskId': 'task-1'}));
      expect(otherChannel.sentMessages, isEmpty);

      await matchingChannel.close();
      await otherChannel.close();
    });

    test('registerWebSocketClient persists incoming chat payloads', () async {
      final channel = _FakeWebSocketChannel();
      service.registerWebSocketClient(
        familyId: 'family-9',
        userId: 'user-42',
        channel: channel,
      );

      final createdMessage = Message(
        id: 'msg-1',
        familyId: 'family-9',
        senderId: 'user-42',
        content: 'From socket',
        createdAt: DateTime.parse('2024-01-01T10:00:00Z'),
      );

      when(() => repository.createMessage(
            familyId: 'family-9',
            senderId: 'user-42',
            content: 'From socket',
          )).thenAnswer((_) async => createdMessage);

      channel.addIncoming(jsonEncode({'type': 'chat:send', 'content': 'From socket'}));

      await Future<void>.delayed(Duration.zero);

      verify(() => repository.createMessage(
            familyId: 'family-9',
            senderId: 'user-42',
            content: 'From socket',
          )).called(1);

      expect(channel.sentMessages, isNotEmpty);
      final payload = jsonDecode(channel.sentMessages.last as String) as Map<String, dynamic>;
      expect(payload['type'], equals('chat:message'));
      expect(payload['familyId'], equals('family-9'));
      expect(payload['data'], equals(createdMessage.toJson()));

      final room = fakeServer.rooms['family:family-9'];
      expect(room, isNotNull);
      expect(room!.emittedEvents.last['event'], equals('chat:message'));

      await channel.close();
    });
  });
}
