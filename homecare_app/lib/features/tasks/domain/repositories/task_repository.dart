import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/entities/task_event.dart';

abstract class TaskRepository {
  Future<List<Task>> fetchTasks({String? familyId});
  Future<Task> createTask({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  });
  Future<Task> fetchTask(String id);
  Future<Task> updateTask(String id, {
    String? title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
    TaskStatus? status,
  });
  Future<void> deleteTask(String id);
  Future<Task> assignTask(String id, String userId);
  Future<Task> completeTaskByQrPayload(String payload);
  Stream<TaskEvent> subscribeToTaskEvents({String? familyId});
  Future<void> close();
}
