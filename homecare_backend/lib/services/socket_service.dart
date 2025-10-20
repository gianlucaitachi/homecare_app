import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:socket_io/socket_io.dart' as io;
import 'package:web_socket_channel/web_socket_channel.dart';

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

  // socket_io 1.0.1 returns a Namespace from [Server.to], so keep this dynamic
  // to support the older API surface.
  final dynamic _room;

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
  final _webSocketClientsByFamily = <String, Set<WebSocketChannel>>{};
  final _familyByWebSocket = <WebSocketChannel, String>{};
  final _userIdByWebSocket = <WebSocketChannel, String>{};

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
    final payload = message.toJson();
    _server
        .toRoom(_roomName(message.familyId))
        .emit('chat:message', payload);
    _emitToWebSocketClients(
      message.familyId,
      _encodeWebSocketEvent(
        type: 'chat:message',
        familyId: message.familyId,
        data: payload,
      ),
    );
  }

  void broadcastTaskUpdated(String familyId, Map<String, dynamic> payload) {
    _server.toRoom(_roomName(familyId)).emit('task:updated', payload);
    _emitToWebSocketClients(
      familyId,
      _encodeWebSocketEvent(
        type: 'task:updated',
        familyId: familyId,
        data: payload,
      ),
    );
  }

  void registerWebSocketClient({
    required String familyId,
    required String userId,
    required WebSocketChannel channel,
  }) {
    final clients =
        _webSocketClientsByFamily.putIfAbsent(familyId, () => <WebSocketChannel>{});
    clients.add(channel);
    _familyByWebSocket[channel] = familyId;
    _userIdByWebSocket[channel] = userId;

    channel.stream.listen(
      (dynamic data) => _handleIncomingWebSocketMessage(channel, data),
      onError: (_) => _removeWebSocketClient(channel),
      onDone: () => _removeWebSocketClient(channel),
      cancelOnError: true,
    );
  }

  Future<void> _handleIncomingWebSocketMessage(
    WebSocketChannel channel,
    dynamic data,
  ) async {
    final familyId = _familyByWebSocket[channel];
    final userId = _userIdByWebSocket[channel];
    if (familyId == null || userId == null) {
      return;
    }

    final payload = _coercePayload(data);
    if (payload == null) {
      return;
    }

    final type = _readString(payload, 'type');
    if (type != null && type != 'chat:send') {
      return;
    }

    final content = _readString(payload, 'content');
    if (content == null || content.trim().isEmpty) {
      return;
    }

    final message = await _messageRepository.createMessage(
      familyId: familyId,
      senderId: userId,
      content: content,
    );

    broadcastChatMessage(message);
  }

  Map<String, dynamic>? _coercePayload(dynamic payload) {
    if (payload is String) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((key, dynamic value) =>
              MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }

    if (payload is Map<String, dynamic>) {
      return payload;
    }

    if (payload is Map) {
      return payload.map((key, dynamic value) =>
          MapEntry(key.toString(), value));
    }

    return null;
  }

  void _emitToWebSocketClients(String familyId, String encodedPayload) {
    final clients = _webSocketClientsByFamily[familyId];
    if (clients == null || clients.isEmpty) {
      return;
    }

    for (final channel in List<WebSocketChannel>.from(clients)) {
      try {
        channel.sink.add(encodedPayload);
      } catch (_) {
        _removeWebSocketClient(channel);
      }
    }
  }

  String _encodeWebSocketEvent({
    required String type,
    required String familyId,
    required Map<String, dynamic> data,
  }) {
    return jsonEncode({
      'type': type,
      'familyId': familyId,
      'data': data,
    });
  }

  void _removeWebSocketClient(WebSocketChannel channel) {
    final familyId = _familyByWebSocket.remove(channel);
    _userIdByWebSocket.remove(channel);
    if (familyId == null) {
      return;
    }

    final clients = _webSocketClientsByFamily[familyId];
    if (clients == null) {
      return;
    }

    clients.remove(channel);
    if (clients.isEmpty) {
      _webSocketClientsByFamily.remove(familyId);
    }
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
