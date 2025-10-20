import 'package:bloc/bloc.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_event.dart';

import 'task_detail_state.dart';

class TaskDetailCubit extends Cubit<TaskDetailState> {
  TaskDetailCubit({
    required TaskRepository repository,
    required TaskBloc taskBloc,
    required this.taskId,
  })  : _repository = repository,
        _taskBloc = taskBloc,
        super(const TaskDetailState());

  final TaskRepository _repository;
  final TaskBloc _taskBloc;
  final String taskId;

  Future<void> load() async {
    emit(state.copyWith(status: TaskDetailStatus.loading, errorMessage: null));
    try {
      final task = await _repository.fetchTask(taskId);
      emit(
        state.copyWith(
          status: TaskDetailStatus.loaded,
          task: task,
          errorMessage: null,
          actionStatus: TaskDetailActionStatus.idle,
          actionMessage: null,
        ),
      );
    } catch (error) {
      emit(
        TaskDetailState(
          status: TaskDetailStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> assignTo(String userId) async {
    emit(state.copyWith(actionStatus: TaskDetailActionStatus.inProgress));
    try {
      final previousTask = state.task;
      final updated = await _repository.assignTask(taskId, userId);
      emit(
        state.copyWith(
          task: updated,
          actionStatus: TaskDetailActionStatus.success,
          actionMessage: 'Assigned to caregiver',
        ),
      );
      if (previousTask != null) {
        _taskBloc.add(
          TaskUpdated(previousTask: previousTask, updatedTask: updated),
        );
      } else {
        _taskBloc.add(TaskCreated(updated));
      }
    } catch (error) {
      emit(
        state.copyWith(
          actionStatus: TaskDetailActionStatus.failure,
          actionMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> completeWithQr(String payload) async {
    emit(state.copyWith(actionStatus: TaskDetailActionStatus.inProgress));
    try {
      final previousTask = state.task;
      final updated = await _repository.completeTaskByQrPayload(payload);
      emit(
        state.copyWith(
          task: updated,
          actionStatus: TaskDetailActionStatus.success,
          actionMessage: 'Task completed',
        ),
      );
      if (previousTask != null) {
        _taskBloc.add(
          TaskUpdated(previousTask: previousTask, updatedTask: updated),
        );
      } else {
        _taskBloc.add(TaskCreated(updated));
      }
    } catch (error) {
      emit(
        state.copyWith(
          actionStatus: TaskDetailActionStatus.failure,
          actionMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> refresh() => load();
}
