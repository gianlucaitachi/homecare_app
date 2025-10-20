import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_event.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_state.dart';
import 'package:homecare_app/features/tasks/presentation/cubit/task_detail_cubit.dart';
import 'package:homecare_app/features/tasks/presentation/cubit/task_detail_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockTaskRepository extends Mock implements TaskRepository {}
class _MockTaskBloc extends MockBloc<TaskEvent, TaskState> implements TaskBloc {}
class _FakeTaskEvent extends Fake implements TaskEvent {}

void main() {
  late _MockTaskRepository repository;
  late _MockTaskBloc taskBloc;
  late TaskDetailCubit cubit;
  final task = Task(
    id: 'task-1',
    familyId: 'family-1',
    title: 'Medication',
    description: 'Provide morning medication',
    status: TaskStatus.pending,
    dueDate: null,
    assignedUserId: null,
    qrPayload: 'payload',
    qrImageBase64: 'data:image/png;base64,aGVsbG8=',
    createdAt: DateTime(2024, 1, 1, 8),
    updatedAt: DateTime(2024, 1, 1, 8),
    completedAt: null,
  );

  setUpAll(() {
    registerFallbackValue(_FakeTaskEvent());
  });

  setUp(() {
    repository = _MockTaskRepository();
    taskBloc = _MockTaskBloc();
    when(() => taskBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => repository.close()).thenAnswer((_) async {});
    cubit = TaskDetailCubit(
      repository: repository,
      taskBloc: taskBloc,
      taskId: task.id,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  test('loads task and emits loaded state', () async {
    when(() => repository.fetchTask(task.id)).thenAnswer((_) async => task);

    expectLater(
      cubit.stream,
      emitsInOrder([
        const TaskDetailState(status: TaskDetailStatus.loading),
        TaskDetailState(status: TaskDetailStatus.loaded, task: task, actionStatus: TaskDetailActionStatus.idle),
      ]),
    );

    await cubit.load();
  });

  test('completes task via QR and updates state', () async {
    final completed = task.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime(2024, 1, 1, 9),
    );

    when(() => repository.fetchTask(task.id)).thenAnswer((_) async => task);
    when(() => repository.completeTaskByQrPayload(task.qrPayload))
        .thenAnswer((_) async => completed);

    await cubit.load();
    await cubit.completeWithQr(task.qrPayload);

    expect(
      cubit.state,
      TaskDetailState(
        status: TaskDetailStatus.loaded,
        task: completed,
        actionStatus: TaskDetailActionStatus.success,
        actionMessage: 'Task completed',
      ),
    );

    verify(
      () => taskBloc.add(
        any(that: isA<TaskUpdated>()),
      ),
    ).called(1);
  });
}
