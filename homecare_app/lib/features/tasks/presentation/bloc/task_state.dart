import 'package:equatable/equatable.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_event.dart';

enum TaskViewStatus { initial, loading, success, failure }

class TaskState extends Equatable {
  const TaskState({
    this.status = TaskViewStatus.initial,
    this.task,
    this.operation,
    this.errorMessage,
  });

  final TaskViewStatus status;
  final Task? task;
  final TaskOperation? operation;
  final String? errorMessage;

  TaskState copyWith({
    TaskViewStatus? status,
    Task? task,
    TaskOperation? operation,
    String? errorMessage,
  }) {
    return TaskState(
      status: status ?? this.status,
      task: task ?? this.task,
      operation: operation ?? this.operation,
      errorMessage: status == TaskViewStatus.failure
          ? (errorMessage ?? this.errorMessage)
          : null,
    );
  }

  @override
  List<Object?> get props => [status, task, operation, errorMessage];
}
