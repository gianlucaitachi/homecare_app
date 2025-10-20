import 'package:equatable/equatable.dart';

import 'task.dart';

enum TaskEventType { created, updated, assigned, completed, deleted }

class TaskEvent extends Equatable {
  const TaskEvent({
    required this.type,
    this.task,
    this.taskId,
    this.familyId,
  });

  final TaskEventType type;
  final Task? task;
  final String? taskId;
  final String? familyId;

  @override
  List<Object?> get props => [type, task, taskId, familyId];
}
