import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/entities/task_event.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_list/task_list_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_list/task_list_event.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_list/task_list_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  late _MockTaskRepository repository;
  final task = Task(
    id: 'task-1',
    familyId: 'family-1',
    title: 'Prepare meal',
    description: 'Prepare breakfast for the family',
    status: TaskStatus.pending,
    dueDate: DateTime(2024, 1, 1),
    assignedUserId: 'caregiver-1',
    qrPayload: 'payload',
    qrImageBase64: 'data:image/png;base64,aGVsbG8=',
    createdAt: DateTime(2023, 12, 31, 8),
    updatedAt: DateTime(2023, 12, 31, 8),
    completedAt: null,
  );

  setUp(() {
    repository = _MockTaskRepository();
    when(() => repository.close()).thenAnswer((_) async {});
  });

  blocTest<TaskListBloc, TaskListState>(
    'emits loading then success when tasks load correctly',
    build: () {
      when(() => repository.fetchTasks(familyId: any(named: 'familyId')))
          .thenAnswer((_) async => [task]);
      when(() => repository.subscribeToTaskEvents(familyId: any(named: 'familyId')))
          .thenAnswer((_) => const Stream<TaskEvent>.empty());
      return TaskListBloc(repository: repository);
    },
    act: (bloc) => bloc.add(const TaskListStarted()),
    expect: () => [
      const TaskListState(status: TaskListStatus.loading),
      TaskListState(status: TaskListStatus.success, tasks: [task]),
    ],
    verify: (_) {
      verify(() => repository.fetchTasks(familyId: any(named: 'familyId'))).called(1);
      verify(() => repository.subscribeToTaskEvents(familyId: any(named: 'familyId')))
          .called(1);
    },
  );

  blocTest<TaskListBloc, TaskListState>(
    'updates tasks when TaskEvent is received',
    build: () {
      when(() => repository.fetchTasks(familyId: any(named: 'familyId')))
          .thenAnswer((_) async => []);
      when(() => repository.subscribeToTaskEvents(familyId: any(named: 'familyId')))
          .thenAnswer((_) => const Stream<TaskEvent>.empty());
      return TaskListBloc(repository: repository);
    },
    act: (bloc) async {
      bloc.add(const TaskListStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(TaskListTaskEventReceived(TaskEvent(type: TaskEventType.created, task: task)));
    },
    expect: () => [
      const TaskListState(status: TaskListStatus.loading),
      const TaskListState(status: TaskListStatus.success, tasks: []),
      TaskListState(status: TaskListStatus.success, tasks: [task]),
    ],
  );
}
