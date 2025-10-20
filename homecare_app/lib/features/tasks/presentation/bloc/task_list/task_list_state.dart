import 'package:equatable/equatable.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';

enum TaskListStatus { initial, loading, success, failure }

class TaskListState extends Equatable {
  const TaskListState({
    this.status = TaskListStatus.initial,
    this.tasks = const <Task>[],
    this.errorMessage,
  });

  final TaskListStatus status;
  final List<Task> tasks;
  final String? errorMessage;

  TaskListState copyWith({
    TaskListStatus? status,
    List<Task>? tasks,
    String? errorMessage,
  }) {
    return TaskListState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, tasks, errorMessage];
}
