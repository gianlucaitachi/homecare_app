import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/entities/task_event.dart'
    as domain;
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_event.dart'
    as task_bloc;

import 'task_list_event.dart';
import 'task_list_state.dart';

class TaskListBloc extends Bloc<TaskListEvent, TaskListState> {
  TaskListBloc({
    required TaskRepository repository,
    required TaskBloc taskBloc,
    this.familyId,
  })  : _repository = repository,
        _taskBloc = taskBloc,
        super(const TaskListState()) {
    on<TaskListStarted>(_onStarted);
    on<TaskListRefreshRequested>(_onRefreshRequested);
    on<TaskListTaskEventReceived>(_onTaskEventReceived);
  }

  final TaskRepository _repository;
  final TaskBloc _taskBloc;
  final String? familyId;
  String? _currentFamilyId;
  StreamSubscription<domain.TaskEvent>? _subscription;

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
    final activeFamilyId = _currentFamilyId ?? familyId;
    final eventFamilyId = taskEvent.familyId ?? taskEvent.task?.familyId;
    if (activeFamilyId != null &&
        eventFamilyId != null &&
        eventFamilyId != activeFamilyId) {
      return;
    }
    final currentTasks = List<Task>.from(state.tasks);
    List<Task>? nextTasks;
    Task? previousTask;
    Task? mutatedTask;
    Task? deletedTask;

    switch (taskEvent.type) {
      case domain.TaskEventType.deleted:
        final taskId = taskEvent.taskId;
        if (taskId == null) {
          break;
        }
        final index = currentTasks.indexWhere((task) => task.id == taskId);
        if (index == -1) {
          break;
        }
        deletedTask = currentTasks.removeAt(index);
        nextTasks = currentTasks;
        break;
      case domain.TaskEventType.created:
      case domain.TaskEventType.updated:
      case domain.TaskEventType.assigned:
      case domain.TaskEventType.completed:
        final task = taskEvent.task;
        if (task == null) {
          return;
        }
        final index = currentTasks.indexWhere((element) => element.id == task.id);
        if (index != -1) {
          previousTask = currentTasks[index];
        }
        mutatedTask = task;
        nextTasks = _upsertTask(currentTasks, task);
        break;
    }

    if (nextTasks == null) {
      return;
    }

    emit(state.copyWith(tasks: nextTasks));

    if (mutatedTask != null) {
      if (previousTask != null) {
        _taskBloc.add(
          task_bloc.TaskUpdated(previousTask: previousTask, updatedTask: mutatedTask),
        );
      } else {
        _taskBloc.add(task_bloc.TaskCreated(mutatedTask));
      }
    } else if (deletedTask != null) {
      _taskBloc.add(task_bloc.TaskDeleted(deletedTask));
    }
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
      final sortedTasks = _sortTasks(tasks);
      emit(
        state.copyWith(
          status: TaskListStatus.success,
          tasks: sortedTasks,
          errorMessage: null,
        ),
      );
      _syncPendingReminders(sortedTasks);
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

  void _syncPendingReminders(List<Task> tasks) {
    final pendingWithDueDate = tasks
        .where((task) => !task.isCompleted && task.dueDate != null)
        .toList();
    if (pendingWithDueDate.isEmpty) {
      return;
    }
    _taskBloc.add(task_bloc.TaskRemindersSynced(pendingWithDueDate));
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
