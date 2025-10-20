import 'package:equatable/equatable.dart';
import 'package:homecare_app/features/tasks/domain/entities/task_event.dart';

abstract class TaskListEvent extends Equatable {
  const TaskListEvent();
}

class TaskListStarted extends TaskListEvent {
  const TaskListStarted({this.familyId});

  final String? familyId;

  @override
  List<Object?> get props => [familyId];
}

class TaskListTaskEventReceived extends TaskListEvent {
  const TaskListTaskEventReceived(this.event);

  final TaskEvent event;

  @override
  List<Object?> get props => [event];
}

class TaskListRefreshRequested extends TaskListEvent {
  const TaskListRefreshRequested();

  @override
  List<Object?> get props => [];
}
