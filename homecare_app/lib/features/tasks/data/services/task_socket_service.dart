import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:homecare_app/core/constants/storage_keys.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class TaskSocketService {
  TaskSocketService({
    required this.baseUrl,
    required FlutterSecureStorage secureStorage,
  }) : _secureStorage = secureStorage;

  final String baseUrl;
  final FlutterSecureStorage _secureStorage;
  WebSocketChannel? _channel;

  Stream<Map<String, dynamic>> connect({String? familyId}) async* {
    await _channel?.sink.close();
    final uri = _buildUri(familyId: familyId);
    final token = await _secureStorage.read(key: StorageKeys.accessToken);
    final headers = token != null
        ? {HttpHeaders.authorizationHeader: 'Bearer $token'}
        : null;
    final channel = IOWebSocketChannel.connect(uri, headers: headers);
    _channel = channel;

    yield* channel.stream.map((event) {
      if (event is String) {
        try {
          final decoded = jsonDecode(event);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (_) {
          return <String, dynamic>{};
        }
      }
      return <String, dynamic>{};
    }).where((event) => event.isNotEmpty);
  }

  Future<void> dispose() async {
    await _channel?.sink.close();
    _channel = null;
  }

  Uri _buildUri({String? familyId}) {
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final segments = <String>[
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      'api',
      'tasks',
      'ws',
    ];

    return Uri(
      scheme: scheme,
      userInfo: base.userInfo.isEmpty ? null : base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      pathSegments: segments,
      queryParameters: familyId != null ? {'familyId': familyId} : null,
    );
  }
}
