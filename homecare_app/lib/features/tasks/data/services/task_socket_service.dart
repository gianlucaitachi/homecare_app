import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class TaskSocketService {
  TaskSocketService({required this.baseUrl});

  final String baseUrl;
  WebSocketChannel? _channel;

  Stream<Map<String, dynamic>> connect({String? familyId}) {
    _channel?.sink.close();
    final uri = _buildUri(familyId: familyId);
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    return channel.stream.map((event) {
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
    final path = base.path.endsWith('/')
        ? '${base.path}ws/tasks'
        : '${base.path}/ws/tasks';
    return Uri(
      scheme: scheme,
      userInfo: base.userInfo.isEmpty ? null : base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
      queryParameters: familyId != null ? {'familyId': familyId} : null,
    );
  }
}
