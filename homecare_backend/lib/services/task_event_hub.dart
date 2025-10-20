import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class TaskEventHub {
  final _clients = <WebSocketChannel>{};

  void addClient(WebSocketChannel channel) {
    _clients.add(channel);
    channel.stream.listen(
      (_) {},
      onError: (_) => _clients.remove(channel),
      onDone: () => _clients.remove(channel),
      cancelOnError: true,
    );
  }

  void broadcast(Map<String, dynamic> event) {
    final payload = jsonEncode(event);
    for (final client in List<WebSocketChannel>.from(_clients)) {
      try {
        client.sink.add(payload);
      } catch (_) {
        unawaited(client.sink.close());
        _clients.remove(client);
      }
    }
  }
}
