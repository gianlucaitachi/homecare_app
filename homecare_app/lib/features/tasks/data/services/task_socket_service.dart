import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/storage_keys.dart';

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
    final token = await _secureStorage.read(key: StorageKeys.accessToken);
    final uri = _buildUri(familyId: familyId, token: token);
    final headers = <String, dynamic>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final channel = WebSocketChannel.connect(
      uri,
      headers: headers.isEmpty ? null : headers,
    );
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

  Uri _buildUri({String? familyId, String? token}) {
    final base = Uri.parse(baseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final pathSegments = [
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      'api',
      'tasks',
      'ws',
    ];
    final queryParameters = <String, String>{
      if (familyId != null) 'familyId': familyId,
      if (token != null && token.isNotEmpty) 'access_token': token,
    };
    return Uri(
      scheme: scheme,
      userInfo: base.userInfo.isEmpty ? null : base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      pathSegments: pathSegments,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }
}
