import 'dart:async';

import 'package:homecare_app/features/tasks/data/datasources/task_local_data_source.dart';
import 'package:homecare_app/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:homecare_app/features/tasks/data/models/task_model.dart';
import 'package:homecare_app/features/tasks/data/services/task_socket_service.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/entities/task_event.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl({
    required TaskRemoteDataSource remoteDataSource,
    required TaskLocalDataSource localDataSource,
    required TaskSocketService socketService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _socketService = socketService;

  final TaskRemoteDataSource _remoteDataSource;
  final TaskLocalDataSource _localDataSource;
  final TaskSocketService _socketService;

  @override
  Future<Task> assignTask(String id, String userId) async {
    final task = await _remoteDataSource.assignTask(id, userId);
    await _localDataSource.upsertTask(task);
    return task;
  }

  @override
  Future<Task> completeTaskByQrPayload(String payload) async {
    final task = await _remoteDataSource.completeTaskByQrPayload(payload);
    await _localDataSource.upsertTask(task);
    return task;
  }

  @override
  Future<Task> createTask({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  }) async {
    final task = await _remoteDataSource.createTask(
      familyId: familyId,
      title: title,
      description: description,
      dueDate: dueDate,
      assignedUserId: assignedUserId,
    );
    await _localDataSource.upsertTask(task);
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    await _remoteDataSource.deleteTask(id);
    await _localDataSource.deleteTask(id);
  }

  @override
  Future<Task> fetchTask(String id) async {
    try {
      final task = await _remoteDataSource.fetchTask(id);
      await _localDataSource.upsertTask(task);
      return task;
    } catch (error) {
      final cached = await _localDataSource.getTask(id);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<Task>> fetchTasks({String? familyId}) async {
    if (familyId == null) {
      final tasks = await _remoteDataSource.fetchTasks();
      for (final task in tasks) {
        await _localDataSource.upsertTask(task);
      }
      return tasks;
    }

    final cached = await _localDataSource.getTasks(familyId);
    try {
      final tasks = await _remoteDataSource.fetchTasks(familyId: familyId);
      await _localDataSource.replaceTasks(familyId, tasks);
      return tasks;
    } catch (error) {
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Stream<TaskEvent> subscribeToTaskEvents({String? familyId}) async* {
    final stream = await _socketService.connect(familyId: familyId);
    yield* stream.asyncMap((event) async {
      final taskEvent = _mapToTaskEvent(event);
      await _applyCacheMutation(taskEvent);
      return taskEvent;
    });
  }

  TaskEvent _mapToTaskEvent(Map<String, dynamic> data) {
    final typeString = data['type'] as String? ?? '';
    TaskEventType type;
    switch (typeString) {
      case 'task.created':
        type = TaskEventType.created;
        break;
      case 'task.assigned':
        type = TaskEventType.assigned;
        break;
      case 'task.completed':
        type = TaskEventType.completed;
        break;
      case 'task.deleted':
        type = TaskEventType.deleted;
        break;
      case 'task.updated':
      default:
        type = TaskEventType.updated;
    }

    Task? task;
    final taskData = data['task'];
    if (taskData is Map<String, dynamic>) {
      task = TaskModel.fromJson(taskData);
    }
    final taskId = data['taskId'] as String? ?? task?.id;
    final familyId =
        data['familyId'] as String? ?? task?.familyId;
    return TaskEvent(
      type: type,
      task: task,
      taskId: taskId,
      familyId: familyId,
    );
  }

  Future<void> _applyCacheMutation(TaskEvent event) async {
    try {
      switch (event.type) {
        case TaskEventType.deleted:
          final taskId = event.taskId;
          if (taskId != null) {
            await _localDataSource.deleteTask(taskId);
          }
          break;
        case TaskEventType.created:
        case TaskEventType.updated:
        case TaskEventType.assigned:
        case TaskEventType.completed:
          final task = event.task;
          if (task is TaskModel) {
            await _localDataSource.upsertTask(task);
          }
          break;
      }
    } catch (_) {
      // Ignore cache synchronization errors to avoid disrupting event stream.
    }
  }

  @override
  Future<Task> updateTask(
    String id, {
    String? title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
    TaskStatus? status,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (dueDate != null) payload['dueDate'] = dueDate.toIso8601String();
    if (assignedUserId != null) payload['assignedUserId'] = assignedUserId;
    if (status != null) payload['status'] = status.apiValue;
    final task = await _remoteDataSource.updateTask(id, payload);
    await _localDataSource.upsertTask(task);
    return task;
  }

  @override
  Future<void> close() => _socketService.dispose();
}
