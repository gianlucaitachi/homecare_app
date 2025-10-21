import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:homecare_app/features/tasks/data/datasources/task_local_data_source.dart';
import 'package:homecare_app/features/tasks/data/models/task_model.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';

void main() {
  late Directory tempDir;
  late TaskLocalDataSource dataSource;

  TaskModel createTask({
    required String id,
    required String familyId,
  }) {
    final createdAt = DateTime.utc(2024, 1, 1, 8);
    return TaskModel(
      id: id,
      familyId: familyId,
      title: 'Task $id',
      description: 'Description for $id',
      status: TaskStatus.pending,
      dueDate: DateTime.utc(2024, 1, 2, 8),
      assignedUserId: 'user-$id',
      qrPayload: 'payload-$id',
      qrImageBase64: 'qr-$id',
      createdAt: createdAt,
      updatedAt: createdAt,
      completedAt: null,
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('task_cache_test');
    Hive.init(tempDir.path);
    dataSource = TaskLocalDataSourceImpl(hive: Hive);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('upsertTask stores and getTasks returns cached tasks', () async {
    final task = createTask(id: 'task-1', familyId: 'family-1');

    await dataSource.upsertTask(task);
    final result = await dataSource.getTasks('family-1');

    expect(result, [task]);
  });

  test('getTask returns cached task by id', () async {
    final task = createTask(id: 'task-2', familyId: 'family-1');

    await dataSource.upsertTask(task);
    final cached = await dataSource.getTask(task.id);

    expect(cached, task);
  });

  test('deleteTask removes cached entry and index mapping', () async {
    final task = createTask(id: 'task-3', familyId: 'family-2');

    await dataSource.upsertTask(task);
    await dataSource.deleteTask(task.id);

    final tasks = await dataSource.getTasks('family-2');
    final cached = await dataSource.getTask(task.id);

    expect(tasks, isEmpty);
    expect(cached, isNull);
  });

  test('replaceTasks mirrors the provided remote list', () async {
    final taskA = createTask(id: 'task-4', familyId: 'family-3');
    final taskB = createTask(id: 'task-5', familyId: 'family-3');
    final taskC = createTask(id: 'task-6', familyId: 'family-3');

    await dataSource.replaceTasks('family-3', [taskA, taskB]);
    await dataSource.replaceTasks('family-3', [taskB, taskC]);

    final tasks = await dataSource.getTasks('family-3');
    final missingTask = await dataSource.getTask(taskA.id);

    expect(tasks, containsAll([taskB, taskC]));
    expect(tasks, hasLength(2));
    expect(missingTask, isNull);
  });
}
