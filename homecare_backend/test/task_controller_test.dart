import 'dart:convert';

import 'package:homecare_backend/controllers/task_controller.dart';
import 'package:homecare_backend/middleware/authentication_middleware.dart';
import 'package:homecare_backend/middleware/authorization_context_middleware.dart';
import 'package:homecare_backend/models/task_model.dart';
import 'package:homecare_backend/models/user_model.dart';
import 'package:homecare_backend/repositories/task_repository.dart';
import 'package:homecare_backend/repositories/user_repository.dart';
import 'package:homecare_backend/services/jwt_service.dart';
import 'package:homecare_backend/services/task_event_hub.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class InMemoryTaskRepository implements TaskRepository {
  final _tasks = <String, Task>{};
  final _uuid = const Uuid();

  @override
  Future<Task?> assignTask(
    String id,
    String userId, {
    required String familyId,
  }) async {
    final task = _tasks[id];
    if (task == null || task.familyId != familyId) return null;
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
  Future<void> deleteTask(String id, {required String familyId}) async {
    final task = _tasks[id];
    if (task == null || task.familyId != familyId) {
      return;
    }
    _tasks.remove(id);
  }

  @override
  Future<Task?> getTask(String id, {required String familyId}) async {
    final task = _tasks[id];
    if (task == null || task.familyId != familyId) return null;
    return task;
  }

  @override
  Future<List<Task>> listTasks({required String familyId}) async {
    return _tasks.values
        .where((task) => task.familyId == familyId)
        .toList();
  }

  @override
  Future<Task?> completeTaskByQrPayload(
    String payload, {
    required String familyId,
  }) async {
    Task? task;
    for (final entry in _tasks.values) {
      if (entry.qrPayload == payload && entry.familyId == familyId) {
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
  Future<Task?> updateTask(
    String id,
    Map<String, dynamic> fields, {
    required String familyId,
  }) async {
    final task = _tasks[id];
    if (task == null || task.familyId != familyId) return null;
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

class InMemoryUserRepository implements UserRepository {
  final Map<String, User> users = {};

  @override
  Future<User?> findUserByEmail(String email) async {
    for (final user in users.values) {
      if (user.email == email) {
        return user;
      }
    }
    return null;
  }

  @override
  Future<User?> findUserById(String id) async => users[id];

  @override
  Future<User> createUser({
    required String id,
    required String name,
    required String email,
    required String passwordHash,
    required String familyId,
    String? familyName,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  group('TaskController', () {
    late InMemoryTaskRepository repository;
    late RecordingTaskEventHub eventHub;
    late TaskController controller;
    late Handler handler;
    late JwtService jwtService;
    late String accessToken;
    late InMemoryUserRepository userRepository;

    setUp(() {
      repository = InMemoryTaskRepository();
      eventHub = RecordingTaskEventHub();
      controller = TaskController(repository, eventHub);
      jwtService = JwtService(
        accessSecret: 'test-access',
        refreshSecret: 'test-refresh',
      );
      accessToken = jwtService.signAccessToken({'sub': 'user-1'});
      userRepository = InMemoryUserRepository()
        ..users['user-1'] = User(
          id: 'user-1',
          name: 'User One',
          email: 'user1@example.com',
          passwordHash: 'hash',
          familyId: 'family-1',
        );
      handler = Pipeline()
          .addMiddleware(authenticationMiddleware(jwtService))
          .addMiddleware(authorizationContextMiddleware(userRepository))
          .addHandler(controller.router.call);
    });

    Request _authedRequest(
      String method,
      String path, {
      Map<String, String>? headers,
      Object? body,
    }) {
      final updatedHeaders = <String, String>{
        'Authorization': 'Bearer $accessToken',
        ...?headers,
      };

      return Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: updatedHeaders,
        body: body,
      );
    }

    Future<Response> _call(Request request) => handler(request);

    test('returns 401 when Authorization header is missing', () async {
      final response = await _call(
        Request('GET', Uri.parse('http://localhost/')),
      );

      expect(response.statusCode, equals(401));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], equals('unauthorized'));
    });

    test('returns 401 when Authorization token is invalid', () async {
      final response = await _call(
        Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'Authorization': 'Bearer invalid-token'},
        ),
      );

      expect(response.statusCode, equals(401));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], equals('unauthorized'));
    });

    test('creates task with QR data and broadcasts event', () async {
      final response = await _call(
        _authedRequest(
          'POST',
          '/',
          body: jsonEncode({
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

    test('lists tasks for authenticated family only', () async {
      userRepository.users['user-1'] = User(
        id: 'user-1',
        name: 'Family Two User',
        email: 'user1@example.com',
        passwordHash: 'hash',
        familyId: 'family-2',
      );

      final createResponse = await _call(
        _authedRequest(
          'POST',
          '/',
          body: jsonEncode({
            'title': 'Prepare breakfast',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );
      final created =
          jsonDecode(await createResponse.readAsString()) as Map<String, dynamic>;
      final taskId = (created['task'] as Map<String, dynamic>)['id'] as String;

      await repository.createTask(
        familyId: 'family-other',
        title: 'Other family task',
      );

      final listResponse = await _call(
        _authedRequest('GET', '/'),
      );

      expect(listResponse.statusCode, equals(200));
      final listBody =
          jsonDecode(await listResponse.readAsString()) as Map<String, dynamic>;
      final tasks = listBody['tasks'] as List<dynamic>;
      expect(tasks, hasLength(1));
      expect(tasks.first['id'], equals(taskId));
      expect(tasks.first['familyId'], equals('family-2'));
    });

    test('list tasks returns 401 without auth context', () async {
      final response = await _call(
        Request('GET', Uri.parse('http://localhost/')),
      );

      expect(response.statusCode, equals(401));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], equals('unauthorized'));
    });

    test('list tasks rejects family override attempts', () async {
      userRepository.users['user-1'] = User(
        id: 'user-1',
        name: 'User Actual',
        email: 'user1@example.com',
        passwordHash: 'hash',
        familyId: 'family-actual',
      );

      final response = await _call(
        _authedRequest('GET', '/?familyId=family-override'),
      );

      expect(response.statusCode, equals(403));
      final body =
          jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], equals('family_id_mismatch'));
    });

    test('list tasks allows override when family matches auth context', () async {
      userRepository.users['user-1'] = User(
        id: 'user-1',
        name: 'Allowed User',
        email: 'user1@example.com',
        passwordHash: 'hash',
        familyId: 'family-allowed',
      );

      await repository.createTask(
        familyId: 'family-allowed',
        title: 'Prepare schedule',
      );

      final response = await _call(
        _authedRequest('GET', '/?familyId=family-allowed'),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      final tasks = body['tasks'] as List<dynamic>;
      expect(tasks, hasLength(1));
      expect(tasks.first['familyId'], equals('family-allowed'));
    });

    test('list tasks returns 401 when authenticated user cannot be resolved',
        () async {
      userRepository.users.remove('user-1');

      final response = await _call(
        _authedRequest('GET', '/'),
      );

      expect(response.statusCode, equals(401));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], equals('unauthorized'));
    });

    test('updates, assigns and completes task', () async {
      userRepository.users['user-1'] = User(
        id: 'user-1',
        name: 'Family Three User',
        email: 'user1@example.com',
        passwordHash: 'hash',
        familyId: 'family-3',
      );

      final createResponse = await _call(
        _authedRequest(
          'POST',
          '/',
          body: jsonEncode({
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
        _authedRequest(
          'PUT',
          '/$taskId',
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
        _authedRequest(
          'POST',
          '/$taskId/assign',
          body: jsonEncode({'userId': 'caregiver-1'}),
          headers: {'content-type': 'application/json'},
        ),
      );
      final assignBody =
          jsonDecode(await assignResponse.readAsString()) as Map<String, dynamic>;
      expect(assignBody['task']['assignedUserId'], equals('caregiver-1'));
      expect(assignBody['task']['status'], equals('in_progress'));

      final completeResponse = await _call(
        _authedRequest(
          'POST',
          '/complete-qr',
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

    test('rejects cross-family task mutations', () async {
      final createResponse = await _call(
        _authedRequest(
          'POST',
          '/',
          body: jsonEncode({
            'title': 'Family one task',
          }),
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(createResponse.statusCode, equals(201));
      final created =
          jsonDecode(await createResponse.readAsString()) as Map<String, dynamic>;
      final task = created['task'] as Map<String, dynamic>;
      final taskId = task['id'] as String;
      final qrPayload = task['qrPayload'] as String;

      userRepository.users['user-1'] = User(
        id: 'user-1',
        name: 'Other Family User',
        email: 'user1@example.com',
        passwordHash: 'hash',
        familyId: 'family-else',
      );

      final updateResponse = await _call(
        _authedRequest(
          'PUT',
          '/$taskId',
          body: jsonEncode({'description': 'Updated'}),
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(updateResponse.statusCode, equals(404));

      final assignResponse = await _call(
        _authedRequest(
          'POST',
          '/$taskId/assign',
          body: jsonEncode({'userId': 'caregiver-99'}),
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(assignResponse.statusCode, equals(404));

      final deleteResponse = await _call(
        _authedRequest('DELETE', '/$taskId'),
      );
      expect(deleteResponse.statusCode, equals(404));

      final completeResponse = await _call(
        _authedRequest(
          'POST',
          '/complete-qr',
          body: jsonEncode({'payload': qrPayload}),
          headers: {'content-type': 'application/json'},
        ),
      );
      expect(completeResponse.statusCode, equals(404));
    });
  });
}
