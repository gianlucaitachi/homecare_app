import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

typedef SocketFactory = SocketClient Function(String uri, Map<String, dynamic> options);

typedef EventHandler = FutureOr<void> Function(dynamic data);

abstract class SocketClient {
  void on(String event, EventHandler handler);

  void emit(String event, dynamic data);

  void connect();

  void disconnect();

  void dispose();

  bool get connected;
}

class SocketIoClientWrapper implements SocketClient {
  SocketIoClientWrapper._(this._socket);

  factory SocketIoClientWrapper(String uri, Map<String, dynamic> options) {
    final socket = io.io(uri, options);
    return SocketIoClientWrapper._(socket);
  }

  final io.Socket _socket;

  @override
  void on(String event, EventHandler handler) {
    _socket.on(event, (data) async {
      await handler(data);
    });
  }

  @override
  void emit(String event, dynamic data) {
    _socket.emit(event, data);
  }

  @override
  void connect() {
    _socket.connect();
  }

  @override
  void disconnect() {
    _socket.disconnect();
  }

  @override
  void dispose() {
    _socket.dispose();
  }

  @override
  bool get connected => _socket.connected;
}

class SocketService {
  SocketService(this._secureStorage, {SocketFactory? socketFactory})
      : _socketFactory = socketFactory ?? SocketIoClientWrapper.new;

  final FlutterSecureStorage _secureStorage;
  final SocketFactory _socketFactory;
  SocketClient? _socket;

  final _chatMessagesController = StreamController<Map<String, dynamic>>.broadcast();
  final _taskUpdatesController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get chatMessages => _chatMessagesController.stream;

  Stream<Map<String, dynamic>> get taskUpdates => _taskUpdatesController.stream;

  Future<void> connect(String baseUrl) async {
    if (_socket != null && _socket!.connected) {
      return;
    }

    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }

    final token = await _secureStorage.read(key: StorageKeys.accessToken);
    _socket = _socketFactory(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'extraHeaders': token != null ? {'Authorization': 'Bearer $token'} : null,
      'autoConnect': false,
    });

    _registerListeners();
    _socket!.connect();
  }

  void _registerListeners() {
    if (_socket == null) return;
    _socket!
      ..on('connect', (_) {})
      ..on('disconnect', (_) {})
      ..on('chat:message', (data) {
        final payload = _coercePayload(data);
        if (payload != null) {
          _chatMessagesController.add(payload);
        }
      })
      ..on('task:updated', (data) {
        final payload = _coercePayload(data);
        if (payload != null) {
          _taskUpdatesController.add(payload);
        }
      });
  }

  void joinRoom(String familyId) {
    _socket?.emit('joinRoom', {'familyId': familyId});
  }

  void sendChatMessage({
    required String familyId,
    required String senderId,
    required String content,
  }) {
    _socket?.emit('chat:send', {
      'familyId': familyId,
      'senderId': senderId,
      'content': content,
    });
  }

  void disconnect() {
    _socket?.disconnect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _chatMessagesController.close();
    _taskUpdatesController.close();
  }

  Map<String, dynamic>? _coercePayload(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    }
    return null;
  }
}
