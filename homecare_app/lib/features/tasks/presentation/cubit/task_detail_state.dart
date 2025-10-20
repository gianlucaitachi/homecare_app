import 'package:equatable/equatable.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';

enum TaskDetailStatus { initial, loading, loaded, failure }

enum TaskDetailActionStatus { idle, inProgress, success, failure }

class TaskDetailState extends Equatable {
  const TaskDetailState({
    this.status = TaskDetailStatus.initial,
    this.task,
    this.errorMessage,
    this.actionStatus = TaskDetailActionStatus.idle,
    this.actionMessage,
  });

  final TaskDetailStatus status;
  final Task? task;
  final String? errorMessage;
  final TaskDetailActionStatus actionStatus;
  final String? actionMessage;

  TaskDetailState copyWith({
    TaskDetailStatus? status,
    Task? task,
    String? errorMessage,
    TaskDetailActionStatus? actionStatus,
    String? actionMessage,
  }) {
    return TaskDetailState(
      status: status ?? this.status,
      task: task ?? this.task,
      errorMessage: errorMessage,
      actionStatus: actionStatus ?? this.actionStatus,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [status, task, errorMessage, actionStatus, actionMessage];
}
