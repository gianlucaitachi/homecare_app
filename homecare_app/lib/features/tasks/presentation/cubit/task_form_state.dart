import 'package:equatable/equatable.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';

enum TaskFormStatus { initial, submitting, success, failure }

class TaskFormState extends Equatable {
  const TaskFormState({
    this.status = TaskFormStatus.initial,
    this.errorMessage,
    this.result,
  });

  final TaskFormStatus status;
  final String? errorMessage;
  final Task? result;

  TaskFormState copyWith({
    TaskFormStatus? status,
    String? errorMessage,
    Task? result,
  }) {
    return TaskFormState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      result: result ?? this.result,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, result];
}
