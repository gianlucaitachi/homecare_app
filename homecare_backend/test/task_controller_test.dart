import 'dart:convert';

import 'package:homecare_backend/controllers/task_controller.dart';
import 'package:homecare_backend/models/task_model.dart';
import 'package:homecare_backend/repositories/task_repository.dart';
import 'package:homecare_backend/services/task_event_hub.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class InMemoryTaskRepository implements TaskRepository {
  final _tasks = <String, Task>{};
  final _uuid = const Uuid();

  @override
  Future<Task?> assignTask(String id, String userId) async {
    final task = _tasks[id];
    if (task == null) return null;
    final updated = task.copyWith(
      assignedUserId: userId,
      status: TaskStatus.inProgress,
      updatedAt: DateTime.now(),
    );
    _tasks[id] = updated;
    return updated;
  }

  @override
  Future<Task> createTask({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final task = Task(
      id: id,
      familyId: familyId,
      assignedUserId: assignedUserId,
      title: title,
      description: description,
      status: TaskStatus.pending,
      dueDate: dueDate,
      qrPayload: 'payload-$id',
      qrImageBase64:
          'data:image/png;base64,${base64Encode(utf8.encode('image-$id'))}',
      createdAt: now,
      updatedAt: now,
      completedAt: null,
    );
    _tasks[id] = task;
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<Task?> getTask(String id) async => _tasks[id];

  @override
  Future<List<Task>> listTasks({String? familyId}) async {
    return _tasks.values
        .where((task) => familyId == null || task.familyId == familyId)
        .toList();
  }

  @override
  Future<Task?> completeTaskByQrPayload(String payload) async {
    Task? task;
    for (final entry in _tasks.values) {
      if (entry.qrPayload == payload) {
        task = entry;
        break;
      }
    }
    if (task == null) return null;
    final updated = task.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _tasks[updated.id] = updated;
    return updated;
  }

  @override
  Future<Task?> updateTask(String id, Map<String, dynamic> fields) async {
    final task = _tasks[id];
    if (task == null) return null;
    var updated = task;
    fields.forEach((key, value) {
      switch (key) {
        case 'title':
          updated = updated.copyWith(title: value as String?);
          break;
        case 'description':
          updated = updated.copyWith(description: value as String?);
          break;
        case 'due_date':
          updated = updated.copyWith(dueDate: value as DateTime?);
          break;
        case 'assigned_user_id':
          updated = updated.copyWith(assignedUserId: value as String?);
          break;
        case 'status':
          updated = updated.copyWith(
            status: TaskStatus.fromString(value as String),
          );
          break;
        case 'completed_at':
          updated = updated.copyWith(completedAt: value as DateTime?);
          break;
      }
    });
    updated = updated.copyWith(updatedAt: DateTime.now());
    _tasks[id] = updated;
    return updated;
  }
}

class RecordingTaskEventHub extends TaskEventHub {
  final events = <Map<String, dynamic>>[];

  @override
  void broadcast(Map<String, dynamic> event) {
    events.add(event);
  }
}

void main() {
  group('TaskController', () {
    late InMemoryTaskRepository repository;
    late RecordingTaskEventHub eventHub;
    late TaskController controller;
    late Handler handler;

    setUp(() {
      repository = InMemoryTaskRepository();
      eventHub = RecordingTaskEventHub();
      controller = TaskController(repository, eventHub);
      handler = controller.router.call;
    });

    Future<Response> _call(Request request) => handler(request);

    test('creates task with QR data and broadcasts event', () async {
      final response = await _call(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          body: jsonEncode({
            'familyId': 'family-1',
            'title': 'Morning medication',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(response.statusCode, equals(201));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      final task = body['task'] as Map<String, dynamic>;
      expect(task['qrPayload'], startsWith('payload-'));
      expect(task['qrImageBase64'], startsWith('data:image/png;base64,'));
      expect(eventHub.events.last['type'], equals('task.created'));
      expect(eventHub.events.last['familyId'], equals('family-1'));
    });

    test('lists tasks after creation', () async {
      final createResponse = await _call(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          body: jsonEncode({
            'familyId': 'family-2',
            'title': 'Prepare breakfast',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );
      final created =
          jsonDecode(await createResponse.readAsString()) as Map<String, dynamic>;
      final taskId = (created['task'] as Map<String, dynamic>)['id'] as String;

      final listResponse = await _call(
        Request('GET', Uri.parse('http://localhost/?familyId=family-2')),
      );

      expect(listResponse.statusCode, equals(200));
      final listBody =
          jsonDecode(await listResponse.readAsString()) as Map<String, dynamic>;
      final tasks = listBody['tasks'] as List<dynamic>;
      expect(tasks, hasLength(1));
      expect(tasks.first['id'], equals(taskId));
    });

    test('updates, assigns and completes task', () async {
      final createResponse = await _call(
        Request(
          'POST',
          Uri.parse('http://localhost/'),
          body: jsonEncode({
            'familyId': 'family-3',
            'title': 'Check vitals',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );
      final created =
          jsonDecode(await createResponse.readAsString()) as Map<String, dynamic>;
      final task = created['task'] as Map<String, dynamic>;
      final taskId = task['id'] as String;
      final qrPayload = task['qrPayload'] as String;

      final updateResponse = await _call(
        Request(
          'PUT',
          Uri.parse('http://localhost/$taskId'),
          body: jsonEncode({
            'description': 'Check blood pressure and heart rate',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(updateResponse.statusCode, equals(200));
      final updatedBody =
          jsonDecode(await updateResponse.readAsString()) as Map<String, dynamic>;
      expect(updatedBody['task']['description'],
          equals('Check blood pressure and heart rate'));

      final assignResponse = await _call(
        Request(
          'POST',
          Uri.parse('http://localhost/$taskId/assign'),
          body: jsonEncode({'userId': 'caregiver-1'}),
          headers: {'content-type': 'application/json'},
        ),
      );
      final assignBody =
          jsonDecode(await assignResponse.readAsString()) as Map<String, dynamic>;
      expect(assignBody['task']['assignedUserId'], equals('caregiver-1'));
      expect(assignBody['task']['status'], equals('in_progress'));

      final completeResponse = await _call(
        Request(
          'POST',
          Uri.parse('http://localhost/complete-qr'),
          body: jsonEncode({'payload': qrPayload}),
          headers: {'content-type': 'application/json'},
        ),
      );
      final completeBody = jsonDecode(await completeResponse.readAsString())
          as Map<String, dynamic>;
      expect(completeBody['task']['status'], equals('completed'));
      expect(eventHub.events.map((e) => e['type']).toSet(),
          containsAll(['task.updated', 'task.assigned', 'task.completed']));
      expect(
        eventHub.events
            .where((event) => event['type'] == 'task.deleted')
            .isEmpty,
        isTrue,
      );
      expect(
        eventHub.events
            .where((event) => event['familyId'] != 'family-3')
            .isEmpty,
        isTrue,
      );
    });
  });
}
