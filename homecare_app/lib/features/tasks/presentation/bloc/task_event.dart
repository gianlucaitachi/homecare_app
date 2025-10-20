import 'package:equatable/equatable.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';

enum TaskOperation { create, update, delete }

abstract class TaskEvent extends Equatable {
  const TaskEvent();
}

class TaskCreated extends TaskEvent {
  const TaskCreated(this.task);

  final Task task;

  @override
  List<Object?> get props => [task];
}

class TaskUpdated extends TaskEvent {
  const TaskUpdated({required this.previousTask, required this.updatedTask});

  final Task previousTask;
  final Task updatedTask;

  @override
  List<Object?> get props => [previousTask, updatedTask];
}

class TaskDeleted extends TaskEvent {
  const TaskDeleted(this.task);

  final Task task;

  @override
  List<Object?> get props => [task];
}
