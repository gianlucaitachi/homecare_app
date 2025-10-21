import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/features/tasks/data/datasources/task_local_data_source.dart';
import 'package:homecare_app/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:homecare_app/features/tasks/data/models/task_model.dart';
import 'package:homecare_app/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:homecare_app/features/tasks/data/services/task_socket_service.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:mocktail/mocktail.dart';

class _MockTaskRemoteDataSource extends Mock implements TaskRemoteDataSource {}

class _MockTaskLocalDataSource extends Mock implements TaskLocalDataSource {}

class _MockTaskSocketService extends Mock implements TaskSocketService {}

void main() {
  late TaskRepositoryImpl repository;
  late _MockTaskRemoteDataSource remoteDataSource;
  late _MockTaskLocalDataSource localDataSource;
  late _MockTaskSocketService socketService;

  TaskModel createTask({
    required String id,
    required String familyId,
    TaskStatus status = TaskStatus.pending,
  }) {
    final timestamp = DateTime.utc(2024, 1, 1, 8);
    return TaskModel(
      id: id,
      familyId: familyId,
      title: 'Task $id',
      description: 'Description for $id',
      status: status,
      dueDate: DateTime.utc(2024, 1, 2, 8),
      assignedUserId: 'user-$id',
      qrPayload: 'payload-$id',
      qrImageBase64: 'qr-$id',
      createdAt: timestamp,
      updatedAt: timestamp,
      completedAt: status == TaskStatus.completed ? timestamp : null,
    );
  }

  setUp(() {
    remoteDataSource = _MockTaskRemoteDataSource();
    localDataSource = _MockTaskLocalDataSource();
    socketService = _MockTaskSocketService();
    repository = TaskRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
      socketService: socketService,
    );
  });

  group('fetchTasks', () {
    test('returns remote tasks and updates the cache when fetch succeeds', () async {
      const familyId = 'family-1';
      final tasks = [
        createTask(id: 'task-1', familyId: familyId),
        createTask(id: 'task-2', familyId: familyId),
      ];

      when(() => localDataSource.getTasks(familyId)).thenAnswer((_) async => []);
      when(() => remoteDataSource.fetchTasks(familyId: familyId))
          .thenAnswer((_) async => tasks);
      when(() => localDataSource.replaceTasks(familyId, tasks))
          .thenAnswer((_) async {});

      final result = await repository.fetchTasks(familyId: familyId);

      expect(result, tasks);
      verify(() => localDataSource.getTasks(familyId)).called(1);
      verify(() => localDataSource.replaceTasks(familyId, tasks)).called(1);
    });

    test('returns cached tasks when remote fetch throws and cache is populated', () async {
      const familyId = 'family-1';
      final cachedTasks = [createTask(id: 'task-3', familyId: familyId)];

      when(() => localDataSource.getTasks(familyId)).thenAnswer((_) async => cachedTasks);
      when(() => remoteDataSource.fetchTasks(familyId: familyId))
          .thenThrow(const SocketException('offline'));

      final result = await repository.fetchTasks(familyId: familyId);

      expect(result, cachedTasks);
      verify(() => localDataSource.getTasks(familyId)).called(1);
      verifyNever(() => localDataSource.replaceTasks(familyId, cachedTasks));
    });

    test('rethrows when remote fetch fails and cache is empty', () async {
      const familyId = 'family-2';

      when(() => localDataSource.getTasks(familyId)).thenAnswer((_) async => []);
      when(() => remoteDataSource.fetchTasks(familyId: familyId))
          .thenThrow(const SocketException('offline'));

      expect(
        () => repository.fetchTasks(familyId: familyId),
        throwsA(isA<SocketException>()),
      );
      verify(() => localDataSource.getTasks(familyId)).called(1);
    });

    test('upserts each task when familyId is not provided', () async {
      final tasks = [
        createTask(id: 'task-4', familyId: 'family-3'),
        createTask(id: 'task-5', familyId: 'family-4'),
      ];

      when(() => remoteDataSource.fetchTasks()).thenAnswer((_) async => tasks);
      when(() => localDataSource.upsertTask(tasks[0])).thenAnswer((_) async {});
      when(() => localDataSource.upsertTask(tasks[1])).thenAnswer((_) async {});

      final result = await repository.fetchTasks();

      expect(result, tasks);
      verify(() => localDataSource.upsertTask(tasks[0])).called(1);
      verify(() => localDataSource.upsertTask(tasks[1])).called(1);
    });
  });

  group('fetchTask', () {
    test('returns remote task and updates the cache on success', () async {
      final task = createTask(id: 'task-6', familyId: 'family-5');

      when(() => remoteDataSource.fetchTask(task.id)).thenAnswer((_) async => task);
      when(() => localDataSource.upsertTask(task)).thenAnswer((_) async {});

      final result = await repository.fetchTask(task.id);

      expect(result, task);
      verify(() => localDataSource.upsertTask(task)).called(1);
    });

    test('returns cached task when remote fetch throws', () async {
      final task = createTask(id: 'task-7', familyId: 'family-6');

      when(() => remoteDataSource.fetchTask(task.id))
          .thenThrow(const SocketException('offline'));
      when(() => localDataSource.getTask(task.id)).thenAnswer((_) async => task);

      final result = await repository.fetchTask(task.id);

      expect(result, task);
      verify(() => localDataSource.getTask(task.id)).called(1);
    });

    test('rethrows when remote fetch fails and no cached task exists', () async {
      const taskId = 'task-8';

      when(() => remoteDataSource.fetchTask(taskId))
          .thenThrow(const SocketException('offline'));
      when(() => localDataSource.getTask(taskId)).thenAnswer((_) async => null);

      expect(
        () => repository.fetchTask(taskId),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('mutations', () {
    test('createTask caches the created task', () async {
      final task = createTask(id: 'task-9', familyId: 'family-7');

      when(
        () => remoteDataSource.createTask(
          familyId: task.familyId,
          title: task.title,
          description: task.description,
          dueDate: task.dueDate,
          assignedUserId: task.assignedUserId,
        ),
      ).thenAnswer((_) async => task);
      when(() => localDataSource.upsertTask(task)).thenAnswer((_) async {});

      final result = await repository.createTask(
        familyId: task.familyId,
        title: task.title,
        description: task.description,
        dueDate: task.dueDate,
        assignedUserId: task.assignedUserId,
      );

      expect(result, task);
      verify(() => localDataSource.upsertTask(task)).called(1);
    });

    test('updateTask caches the updated task', () async {
      final task = createTask(id: 'task-10', familyId: 'family-8');

      when(() => remoteDataSource.updateTask(task.id, {'title': task.title}))
          .thenAnswer((_) async => task);
      when(() => localDataSource.upsertTask(task)).thenAnswer((_) async {});

      final result = await repository.updateTask(task.id, title: task.title);

      expect(result, task);
      verify(() => localDataSource.upsertTask(task)).called(1);
    });

    test('deleteTask removes the cached task', () async {
      const taskId = 'task-11';

      when(() => remoteDataSource.deleteTask(taskId)).thenAnswer((_) async {});
      when(() => localDataSource.deleteTask(taskId)).thenAnswer((_) async {});

      await repository.deleteTask(taskId);

      verify(() => localDataSource.deleteTask(taskId)).called(1);
    });

    test('assignTask caches the returned task', () async {
      final task = createTask(id: 'task-12', familyId: 'family-9');

      when(() => remoteDataSource.assignTask(task.id, 'user-1'))
          .thenAnswer((_) async => task);
      when(() => localDataSource.upsertTask(task)).thenAnswer((_) async {});

      final result = await repository.assignTask(task.id, 'user-1');

      expect(result, task);
      verify(() => localDataSource.upsertTask(task)).called(1);
    });

    test('completeTaskByQrPayload caches the returned task', () async {
      final task = createTask(
        id: 'task-13',
        familyId: 'family-10',
        status: TaskStatus.completed,
      );

      when(() => remoteDataSource.completeTaskByQrPayload('payload'))
          .thenAnswer((_) async => task);
      when(() => localDataSource.upsertTask(task)).thenAnswer((_) async {});

      final result = await repository.completeTaskByQrPayload('payload');

      expect(result, task);
      verify(() => localDataSource.upsertTask(task)).called(1);
    });
  });
}
