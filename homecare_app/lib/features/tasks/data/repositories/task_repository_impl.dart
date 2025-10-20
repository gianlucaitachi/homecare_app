import 'package:homecare_app/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:homecare_app/features/tasks/data/models/task_model.dart';
import 'package:homecare_app/features/tasks/data/services/task_socket_service.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/entities/task_event.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl({
    required TaskRemoteDataSource remoteDataSource,
    required TaskSocketService socketService,
  })  : _remoteDataSource = remoteDataSource,
        _socketService = socketService;

  final TaskRemoteDataSource _remoteDataSource;
  final TaskSocketService _socketService;

  @override
  Future<Task> assignTask(String id, String userId) =>
      _remoteDataSource.assignTask(id, userId);

  @override
  Future<Task> completeTaskByQrPayload(String payload) =>
      _remoteDataSource.completeTaskByQrPayload(payload);

  @override
  Future<Task> createTask({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  }) {
    return _remoteDataSource.createTask(
      familyId: familyId,
      title: title,
      description: description,
      dueDate: dueDate,
      assignedUserId: assignedUserId,
    );
  }

  @override
  Future<void> deleteTask(String id) => _remoteDataSource.deleteTask(id);

  @override
  Future<Task> fetchTask(String id) => _remoteDataSource.fetchTask(id);

  @override
  Future<List<Task>> fetchTasks({String? familyId}) =>
      _remoteDataSource.fetchTasks(familyId: familyId);

  @override
  Stream<TaskEvent> subscribeToTaskEvents({String? familyId}) {
    return _socketService.connect(familyId: familyId).map(_mapToTaskEvent);
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
    return TaskEvent(type: type, task: task, taskId: taskId);
  }

  @override
  Future<Task> updateTask(
    String id, {
    String? title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
    TaskStatus? status,
  }) {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (dueDate != null) payload['dueDate'] = dueDate.toIso8601String();
    if (assignedUserId != null) payload['assignedUserId'] = assignedUserId;
    if (status != null) payload['status'] = status.apiValue;
    return _remoteDataSource.updateTask(id, payload);
  }

  @override
  Future<void> close() => _socketService.dispose();
}
