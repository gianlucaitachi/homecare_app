import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class TaskEventHub {
  final _clientsByFamily = <String?, Set<WebSocketChannel>>{};
  final _familiesByChannel = <WebSocketChannel, String?>{};

  void addClient(
    WebSocketChannel channel, {
    String? familyId,
  }) {
    final clients =
        _clientsByFamily.putIfAbsent(familyId, () => <WebSocketChannel>{});
    clients.add(channel);
    _familiesByChannel[channel] = familyId;

    channel.stream.listen(
      (_) {},
      onError: (_) => _removeClient(channel),
      onDone: () => _removeClient(channel),
      cancelOnError: true,
    );
  }

  void broadcast(Map<String, dynamic> event) {
    final payload = jsonEncode(event);
    final targetFamily = event['familyId'] as String?;
    final targets = <WebSocketChannel>{};

    final familyClients = _clientsByFamily[targetFamily];
    if (familyClients != null) {
      targets.addAll(familyClients);
    }

    final globalClients = _clientsByFamily[null];
    if (globalClients != null) {
      targets.addAll(globalClients);
    }

    for (final client in List<WebSocketChannel>.from(targets)) {
      try {
        client.sink.add(payload);
      } catch (_) {
        unawaited(client.sink.close());
        _removeClient(client);
      }
    }
  }

  void _removeClient(WebSocketChannel channel) {
    final familyId = _familiesByChannel.remove(channel);
    if (familyId != null) {
      final clients = _clientsByFamily[familyId];
      if (clients == null) {
        return;
      }
      clients.remove(channel);
      if (clients.isEmpty) {
        _clientsByFamily.remove(familyId);
      }
      return;
    }

    for (final entry in _clientsByFamily.entries.toList()) {
      entry.value.remove(channel);
      if (entry.value.isEmpty) {
        _clientsByFamily.remove(entry.key);
      }
    }
  }
}
