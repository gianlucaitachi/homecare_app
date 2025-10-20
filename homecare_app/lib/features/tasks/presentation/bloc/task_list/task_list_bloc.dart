import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/entities/task_event.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';

import 'task_list_event.dart';
import 'task_list_state.dart';

class TaskListBloc extends Bloc<TaskListEvent, TaskListState> {
  TaskListBloc({
    required TaskRepository repository,
    this.familyId,
  })  : _repository = repository,
        super(const TaskListState()) {
    on<TaskListStarted>(_onStarted);
    on<TaskListRefreshRequested>(_onRefreshRequested);
    on<TaskListTaskEventReceived>(_onTaskEventReceived);
  }

  final TaskRepository _repository;
  final String? familyId;
  String? _currentFamilyId;
  StreamSubscription<TaskEvent>? _subscription;

  Future<void> _onStarted(
    TaskListStarted event,
    Emitter<TaskListState> emit,
  ) async {
    _currentFamilyId = event.familyId ?? familyId;
    await _loadTasks(emit, familyId: _currentFamilyId);
    _subscribeToEvents();
  }

  Future<void> _onRefreshRequested(
    TaskListRefreshRequested event,
    Emitter<TaskListState> emit,
  ) async {
    await _loadTasks(emit, familyId: _currentFamilyId, keepStatus: true);
  }

  void _onTaskEventReceived(
    TaskListTaskEventReceived event,
    Emitter<TaskListState> emit,
  ) {
    if (state.status != TaskListStatus.success) {
      return;
    }
    final taskEvent = event.event;
    var tasks = List<Task>.from(state.tasks);
    switch (taskEvent.type) {
      case TaskEventType.deleted:
        tasks.removeWhere((task) => task.id == taskEvent.taskId);
        break;
      case TaskEventType.created:
      case TaskEventType.updated:
      case TaskEventType.assigned:
      case TaskEventType.completed:
        final task = taskEvent.task;
        if (task == null) return;
        tasks = _upsertTask(tasks, task);
        break;
    }

    emit(state.copyWith(tasks: tasks));
  }

  Future<void> _loadTasks(
    Emitter<TaskListState> emit, {
    String? familyId,
    bool keepStatus = false,
  }) async {
    if (!keepStatus) {
      emit(state.copyWith(status: TaskListStatus.loading, errorMessage: null));
    }
    try {
      final tasks = await _repository.fetchTasks(familyId: familyId);
      emit(
        state.copyWith(
          status: TaskListStatus.success,
          tasks: _sortTasks(tasks),
          errorMessage: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: TaskListStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void _subscribeToEvents() {
    _subscription?.cancel();
    _subscription = _repository
        .subscribeToTaskEvents(familyId: _currentFamilyId)
        .listen((event) => add(TaskListTaskEventReceived(event)));
  }

  List<Task> _upsertTask(List<Task> tasks, Task task) {
    final updated = List<Task>.from(tasks);
    final index = updated.indexWhere((element) => element.id == task.id);
    if (index >= 0) {
      updated[index] = task;
    } else {
      updated.insert(0, task);
    }
    return _sortTasks(updated);
  }

  List<Task> _sortTasks(List<Task> tasks) {
    final sorted = List<Task>.from(tasks);
    sorted.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      final aDue = a.dueDate;
      final bDue = b.dueDate;
      if (aDue == null && bDue == null) {
        return b.createdAt.compareTo(a.createdAt);
      } else if (aDue == null) {
        return 1;
      } else if (bDue == null) {
        return -1;
      } else {
        return aDue.compareTo(bDue);
      }
    });
    return sorted;
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _repository.close();
    return super.close();
  }
}
