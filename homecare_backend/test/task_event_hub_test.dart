import 'dart:async';
import 'dart:convert';

import 'package:homecare_backend/services/task_event_hub.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _TestWebSocketSink implements WebSocketSink {
  final messages = <dynamic>[];
  bool closed = false;
  final _doneCompleter = Completer<void>();

  @override
  void add(dynamic data) {
    messages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final event in stream) {
      add(event);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) {
    closed = true;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    return Future.value();
  }

  @override
  Future<void> get done => _doneCompleter.future;
}

class _TestTaskEventClient implements TaskEventClient {
  _TestTaskEventClient() : _controller = StreamController<dynamic>();

  final StreamController<dynamic> _controller;
  final _sink = _TestWebSocketSink();

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  WebSocketSink get sink => _sink;

  List<dynamic> get messages => _sink.messages;

  void close() {
    _controller.close();
  }

  void addError(Object error) {
    _controller.addError(error);
  }
}

void main() {
  group('TaskEventHub', () {
    test('broadcasts only to matching family', () {
      final hub = TaskEventHub();
      final family1 = _TestTaskEventClient();
      final family2 = _TestTaskEventClient();
      final global = _TestTaskEventClient();

      hub.addClient(family1, familyId: 'family-1');
      hub.addClient(family2, familyId: 'family-2');
      hub.addClient(global);

      hub.broadcast({'type': 'task.updated', 'familyId': 'family-1'});

      expect(family1.messages, hasLength(1));
      expect(
        jsonDecode(family1.messages.first as String)['familyId'],
        equals('family-1'),
      );
      expect(family2.messages, isEmpty);
      expect(global.messages, hasLength(1));
    });

    test('removes disconnected clients from their family set', () async {
      final hub = TaskEventHub();
      final family1 = _TestTaskEventClient();

      hub.addClient(family1, familyId: 'family-1');
      family1.close();
      await Future<void>.delayed(Duration.zero);

      hub.broadcast({'type': 'task.updated', 'familyId': 'family-1'});

      expect(family1.messages, isEmpty);
    });
  });
}
