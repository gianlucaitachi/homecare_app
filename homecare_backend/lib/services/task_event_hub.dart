import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

abstract class TaskEventClient {
  Stream<dynamic> get stream;

  WebSocketSink get sink;
}

class WebSocketTaskEventClient implements TaskEventClient {
  WebSocketTaskEventClient(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  WebSocketSink get sink => _channel.sink;
}

class TaskEventHub {
  final _clientsByFamily = <String?, Set<TaskEventClient>>{};
  final _familiesByChannel = <TaskEventClient, String?>{};

  void addClient(
    TaskEventClient client, {
    String? familyId,
  }) {
    final clients =
        _clientsByFamily.putIfAbsent(familyId, () => <TaskEventClient>{});
    clients.add(client);
    _familiesByChannel[client] = familyId;

    client.stream.listen(
      (_) {},
      onError: (_) => _removeClient(client),
      onDone: () => _removeClient(client),
      cancelOnError: true,
    );
  }

  void broadcast(Map<String, dynamic> event) {
    final payload = jsonEncode(event);
    final targetFamily = event['familyId'] as String?;
    final targets = <TaskEventClient>{};

    final familyClients = _clientsByFamily[targetFamily];
    if (familyClients != null) {
      targets.addAll(familyClients);
    }

    final globalClients = _clientsByFamily[null];
    if (globalClients != null) {
      targets.addAll(globalClients);
    }

    for (final client in List<TaskEventClient>.from(targets)) {
      try {
        client.sink.add(payload);
      } catch (_) {
        unawaited(client.sink.close());
        _removeClient(client);
      }
    }
  }

  void _removeClient(TaskEventClient client) {
    final familyId = _familiesByChannel.remove(client);
    if (familyId != null) {
      final clients = _clientsByFamily[familyId];
      if (clients == null) {
        return;
      }
      clients.remove(client);
      if (clients.isEmpty) {
        _clientsByFamily.remove(familyId);
      }
      return;
    }

    for (final entry in _clientsByFamily.entries.toList()) {
      entry.value.remove(client);
      if (entry.value.isEmpty) {
        _clientsByFamily.remove(entry.key);
      }
    }
  }
}
