import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homecare_app/core/constants/storage_keys.dart';
import 'package:homecare_app/features/tasks/data/services/task_socket_service.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaskSocketService integration', () {
    late HttpServer server;
    late _MockSecureStorage secureStorage;
    late TaskSocketService service;
    HttpRequest? upgradeRequest;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0);
      secureStorage = _MockSecureStorage();
      when(() => secureStorage.read(key: any(named: 'key')))
          .thenAnswer((invocation) async => 'token-123');

      server.listen((request) async {
        if (request.uri.path == '/api/tasks/ws') {
          upgradeRequest = request;
          final socket = await WebSocketTransformer.upgrade(request);
          socket.add(jsonEncode({
            'type': 'task.created',
            'taskId': 'task-1',
            'familyId': request.uri.queryParameters['familyId'],
          }));
          await socket.close();
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });

      service = TaskSocketService(
        baseUrl: 'http://localhost:${server.port}',
        secureStorage: secureStorage,
      );
    });

    tearDown(() async {
      await service.dispose();
      await server.close(force: true);
    });

    test('connects under /api namespace with bearer token and streams events', () async {
      final events = await service
          .connect(familyId: 'family-1')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events.single['type'], 'task.created');
      expect(events.single['familyId'], 'family-1');
      expect(upgradeRequest, isNotNull);
      expect(upgradeRequest!.uri.path, '/api/tasks/ws');
      expect(upgradeRequest!.uri.queryParameters['familyId'], 'family-1');
      expect(
        upgradeRequest!.headers.value(HttpHeaders.authorizationHeader),
        'Bearer token-123',
      );

      verify(() => secureStorage.read(key: StorageKeys.accessToken)).called(1);
    });
  });
}
