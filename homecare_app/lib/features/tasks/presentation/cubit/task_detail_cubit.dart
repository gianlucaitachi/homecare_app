import 'package:bloc/bloc.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';

import 'task_detail_state.dart';

class TaskDetailCubit extends Cubit<TaskDetailState> {
  TaskDetailCubit({
    required TaskRepository repository,
    required this.taskId,
  })  : _repository = repository,
        super(const TaskDetailState());

  final TaskRepository _repository;
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
      final updated = await _repository.assignTask(taskId, userId);
      emit(
        state.copyWith(
          task: updated,
          actionStatus: TaskDetailActionStatus.success,
          actionMessage: 'Assigned to caregiver',
        ),
      );
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
      final updated = await _repository.completeTaskByQrPayload(payload);
      emit(
        state.copyWith(
          task: updated,
          actionStatus: TaskDetailActionStatus.success,
          actionMessage: 'Task completed',
        ),
      );
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
