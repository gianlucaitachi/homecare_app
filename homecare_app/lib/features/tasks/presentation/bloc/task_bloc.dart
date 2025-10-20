import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/core/notifications/notification_service.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_event.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  TaskBloc({required NotificationService notificationService})
      : _notificationService = notificationService,
        super(const TaskState()) {
    on<TaskCreated>(_onTaskCreated);
    on<TaskUpdated>(_onTaskUpdated);
    on<TaskDeleted>(_onTaskDeleted);
  }

  final NotificationService _notificationService;

  Future<void> _onTaskCreated(TaskCreated event, Emitter<TaskState> emit) async {
    emit(state.copyWith(status: TaskStatus.loading));

    try {
      await _scheduleReminderIfNeeded(event.task);
      emit(
        state.copyWith(
          status: TaskStatus.success,
          task: event.task,
          operation: TaskOperation.create,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: TaskStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onTaskUpdated(TaskUpdated event, Emitter<TaskState> emit) async {
    emit(state.copyWith(status: TaskStatus.loading));

    try {
      await _updateReminderForUpdate(event.previousTask, event.updatedTask);
      emit(
        state.copyWith(
          status: TaskStatus.success,
          task: event.updatedTask,
          operation: TaskOperation.update,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: TaskStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onTaskDeleted(TaskDeleted event, Emitter<TaskState> emit) async {
    emit(state.copyWith(status: TaskStatus.loading));

    try {
      await _notificationService.cancelTaskReminder(event.task.id);
      emit(
        state.copyWith(
          status: TaskStatus.success,
          task: event.task,
          operation: TaskOperation.delete,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: TaskStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _scheduleReminderIfNeeded(Task task) async {
    final dueDate = task.dueDate;
    if (dueDate == null) {
      await _notificationService.cancelTaskReminder(task.id);
      return;
    }

    await _notificationService.scheduleTaskReminder(
      taskId: task.id,
      title: task.title,
      body: _buildReminderBody(task),
      dueDate: dueDate,
    );
  }

  Future<void> _updateReminderForUpdate(Task previous, Task updated) async {
    final previousDueDate = previous.dueDate;
    final newDueDate = updated.dueDate;

    if (newDueDate == null) {
      if (previousDueDate != null) {
        await _notificationService.cancelTaskReminder(updated.id);
      }
      return;
    }

    await _notificationService.updateTaskReminder(
      taskId: updated.id,
      title: updated.title,
      body: _buildReminderBody(updated),
      dueDate: newDueDate,
    );
  }

  String _buildReminderBody(Task task) {
    final description = task.description;
    if (description != null && description.trim().isNotEmpty) {
      return description;
    }
    return 'Task "${task.title}" is due soon.';
  }
}
