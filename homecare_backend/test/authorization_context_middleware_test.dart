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
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

class _InMemoryUserRepository implements UserRepository {
  _InMemoryUserRepository(this._users);

  final Map<String, User> _users;

  @override
  Future<User?> findUserByEmail(String email) async {
    for (final user in _users.values) {
      if (user.email == email) {
        return user;
      }
    }
    return null;
  }

  @override
  Future<User?> findUserById(String id) async => _users[id];

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

class _StubTaskRepository implements TaskRepository {
  _StubTaskRepository(this._tasks);

  final Map<String, Task> _tasks;

  @override
  Future<Task?> assignTask(String id, String userId) {
    throw UnimplementedError();
  }

  @override
  Future<Task> createTask({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTask(String id) {
    throw UnimplementedError();
  }

  @override
  Future<Task?> getTask(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<Task>> listTasks({required String familyId}) async {
    return _tasks.values
        .where((task) => task.familyId == familyId)
        .toList(growable: false);
  }

  @override
  Future<Task?> completeTaskByQrPayload(String payload) {
    throw UnimplementedError();
  }

  @override
  Future<Task?> updateTask(String id, Map<String, dynamic> fields) {
    throw UnimplementedError();
  }
}

void main() {
  group('authorizationContextMiddleware', () {
    late JwtService jwtService;
    late Handler handler;

    setUp(() {
      jwtService = JwtService(
        accessSecret: 'access-secret',
        refreshSecret: 'refresh-secret',
      );

      final user = User(
        id: 'user-123',
        name: 'Test User',
        email: 'user@example.com',
        passwordHash: 'hash',
        familyId: 'family-123',
      );

      final userRepository = _InMemoryUserRepository({user.id: user});
      final task = Task(
        id: 'task-1',
        familyId: 'family-123',
        title: 'Task for family 123',
        description: null,
        status: TaskStatus.pending,
        assignedUserId: null,
        dueDate: null,
        qrPayload: 'payload-1',
        qrImageBase64: 'image',
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 1, 1),
        completedAt: null,
      );
      final otherTask = task.copyWith(
        id: 'task-2',
        familyId: 'family-999',
        title: 'Other family task',
        qrPayload: 'payload-2',
      );
      final taskRepository =
          _StubTaskRepository({task.id: task, otherTask.id: otherTask});
      final taskController = TaskController(taskRepository, TaskEventHub());

      final router = Router()..mount('/api/tasks', taskController.router);

      handler = Pipeline()
          .addMiddleware(authenticationMiddleware(jwtService))
          .addMiddleware(authorizationContextMiddleware(userRepository))
          .addHandler(router.call);
    });

    test('GET /api/tasks returns tasks for authenticated user family', () async {
      final token = jwtService.signAccessToken({'sub': 'user-123'});
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/tasks'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final response = await handler(request);
      expect(response.statusCode, equals(200));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      final tasks = body['tasks'] as List<dynamic>;
      expect(tasks, hasLength(1));
      expect(tasks.first['familyId'], equals('family-123'));
    });

    test('GET /api/tasks rejects mismatched family overrides', () async {
      final token = jwtService.signAccessToken({'sub': 'user-123'});
      final request = Request(
        'GET',
        Uri.parse('http://localhost/api/tasks?familyId=family-999'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final response = await handler(request);
      expect(response.statusCode, equals(403));
      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], equals('family_id_mismatch'));
    });
  });
}
