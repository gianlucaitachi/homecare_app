import 'dart:async';
import 'dart:io';

import 'package:socket_io/socket_io.dart' as io;

import '../models/message_model.dart';
import '../repositories/message_repository.dart';

String _roomName(String familyId) => 'family:$familyId';

abstract class SocketRoom {
  void emit(String event, dynamic data);
}

abstract class SocketClient {
  void join(String room);

  void on(String event, FutureOr<void> Function(dynamic data) handler);
}

abstract class SocketServerAdapter {
  void attach(HttpServer server);

  void onConnection(void Function(SocketClient client) handler);

  SocketRoom toRoom(String room);
}

class SocketIOServerAdapter implements SocketServerAdapter {
  SocketIOServerAdapter({io.Server? server}) : _server = server ?? io.Server();

  final io.Server _server;

  @override
  void attach(HttpServer server) {
    _server.attach(server);
  }

  @override
  void onConnection(void Function(SocketClient client) handler) {
    _server.on('connection', (client) {
      handler(_SocketIOClientAdapter(client as io.Socket));
    });
  }

  @override
  SocketRoom toRoom(String room) {
    return _SocketIORoomAdapter(_server.to(room));
  }
}

class _SocketIORoomAdapter implements SocketRoom {
  _SocketIORoomAdapter(this._room);

  final io.BroadcastOperator _room;

  @override
  void emit(String event, dynamic data) {
    _room.emit(event, data);
  }
}

class _SocketIOClientAdapter implements SocketClient {
  _SocketIOClientAdapter(this._client);

  final io.Socket _client;

  @override
  void join(String room) {
    _client.join(room);
  }

  @override
  void on(String event, FutureOr<void> Function(dynamic data) handler) {
    _client.on(event, (data) async {
      await handler(data);
    });
  }
}

class SocketService {
  SocketService({
    required SocketServerAdapter server,
    required MessageRepository messageRepository,
  })  : _server = server,
        _messageRepository = messageRepository;

  final SocketServerAdapter _server;
  final MessageRepository _messageRepository;

  void initialize() {
    _server.onConnection((client) {
      client.on('joinRoom', (payload) {
        final familyId = _readString(payload, 'familyId');
        if (familyId == null) return;
        client.join(_roomName(familyId));
      });

      client.on('chat:send', (payload) async {
        final familyId = _readString(payload, 'familyId');
        final senderId = _readString(payload, 'senderId');
        final content = _readString(payload, 'content');
        if (familyId == null || senderId == null || content == null || content.trim().isEmpty) {
          return;
        }

        final message = await _messageRepository.createMessage(
          familyId: familyId,
          senderId: senderId,
          content: content,
        );

        broadcastChatMessage(message);
      });
    });
  }

  void attachToHttpServer(HttpServer server) {
    _server.attach(server);
  }

  void broadcastChatMessage(Message message) {
    _server.toRoom(_roomName(message.familyId)).emit('chat:message', message.toJson());
  }

  void broadcastTaskUpdated(String familyId, Map<String, dynamic> payload) {
    _server.toRoom(_roomName(familyId)).emit('task:updated', payload);
  }

  String? _readString(dynamic payload, String key) {
    if (payload is Map<String, dynamic> && payload[key] is String) {
      return payload[key] as String;
    }
    if (payload is Map && payload[key] is String) {
      return payload[key] as String;
    }
    return null;
  }
}
