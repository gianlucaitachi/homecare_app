import 'dart:convert';

import 'package:homecare_backend/controllers/task_controller.dart';
import 'package:homecare_backend/services/socket_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class _MockSocketService extends Mock implements SocketService {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('TaskController', () {
    late _MockSocketService socketService;
    late TaskController controller;

    setUp(() {
      socketService = _MockSocketService();
      controller = TaskController(socketService);
    });

    test('broadcastUpdate validates familyId', () async {
      final request = Request('POST', Uri.parse('http://localhost/tasks/1/events/updated'), body: jsonEncode({}));

      final response = await controller.broadcastUpdate(request, 'task-1');

      expect(response.statusCode, equals(400));
    });

    test('broadcastUpdate forwards payload to socket service', () async {
      when(() => socketService.broadcastTaskUpdated('family-1', any())).thenReturn(null);

      final request = Request(
        'POST',
        Uri.parse('http://localhost/tasks/1/events/updated'),
        body: jsonEncode({
          'familyId': 'family-1',
          'changes': {'status': 'done'},
        }),
      );

      final response = await controller.broadcastUpdate(request, 'task-1');

      expect(response.statusCode, equals(200));
      verify(() => socketService.broadcastTaskUpdated('family-1', {
            'taskId': 'task-1',
            'changes': {'status': 'done'},
          })).called(1);
    });
  });
}
