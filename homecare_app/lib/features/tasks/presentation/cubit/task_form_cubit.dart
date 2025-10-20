import 'package:bloc/bloc.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_event.dart';

import 'task_form_state.dart';

class TaskFormCubit extends Cubit<TaskFormState> {
  TaskFormCubit({
    required TaskRepository repository,
    required TaskBloc taskBloc,
    this.initialTask,
  })  : _repository = repository,
        _taskBloc = taskBloc,
        super(TaskFormState(result: initialTask));

  final TaskRepository _repository;
  final TaskBloc _taskBloc;
  final Task? initialTask;

  bool get isEditing => initialTask != null;

  Future<void> submit({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  }) async {
    emit(state.copyWith(status: TaskFormStatus.submitting, errorMessage: null));
    try {
      final task = await _submit(
        familyId: familyId,
        title: title,
        description: description,
        dueDate: dueDate,
        assignedUserId: assignedUserId,
      );
      if (initialTask == null) {
        _taskBloc.add(TaskCreated(task));
      } else {
        _taskBloc.add(
          TaskUpdated(previousTask: initialTask!, updatedTask: task),
        );
      }
      emit(
        state.copyWith(
          status: TaskFormStatus.success,
          result: task,
          errorMessage: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: TaskFormStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<Task> _submit({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  }) {
    if (initialTask == null) {
      return _repository.createTask(
        familyId: familyId,
        title: title,
        description: description,
        dueDate: dueDate,
        assignedUserId: assignedUserId,
      );
    }
    return _repository.updateTask(
      initialTask!.id,
      title: title,
      description: description,
      dueDate: dueDate,
      assignedUserId: assignedUserId,
    );
  }
}
