import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/entities/task_event.dart'
    as domain_event;
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_event.dart'
    as task_bloc_event;
import 'package:homecare_app/features/tasks/presentation/bloc/task_list/task_list_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_list/task_list_event.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_list/task_list_state.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockTaskRepository extends Mock implements TaskRepository {}
class _MockTaskBloc extends MockBloc<task_bloc_event.TaskEvent, TaskState>
    implements TaskBloc {}

class _FakeTaskEvent extends Fake implements task_bloc_event.TaskEvent {}

void main() {
  late _MockTaskRepository repository;
  late _MockTaskBloc taskBloc;
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
  final _dueTask = task.copyWith(
    dueDate: DateTime(2024, 2, 1),
    status: TaskStatus.pending,
  );

  setUpAll(() {
    registerFallbackValue(_FakeTaskEvent());
  });

  setUp(() {
    repository = _MockTaskRepository();
    taskBloc = _MockTaskBloc();
    when(() => taskBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => taskBloc.add(any())).thenReturn(null);
    when(() => repository.close()).thenAnswer((_) async {});
  });

  blocTest<TaskListBloc, TaskListState>(
    'emits loading then success when tasks load correctly',
    build: () {
      when(() => repository.fetchTasks(familyId: any(named: 'familyId')))
          .thenAnswer((_) async => [task]);
      when(() => repository.subscribeToTaskEvents(familyId: any(named: 'familyId')))
          .thenAnswer((_) => const Stream<domain_event.TaskEvent>.empty());
      return TaskListBloc(repository: repository, taskBloc: taskBloc);
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
      verify(
        () => taskBloc.add(
          any(that: isA<task_bloc_event.TaskRemindersSynced>()),
        ),
      ).called(1);
    },
  );

  blocTest<TaskListBloc, TaskListState>(
    'updates tasks when TaskEvent is received',
    build: () {
      when(() => repository.fetchTasks(familyId: any(named: 'familyId')))
          .thenAnswer((_) async => []);
      when(() => repository.subscribeToTaskEvents(familyId: any(named: 'familyId')))
          .thenAnswer((_) => const Stream<domain_event.TaskEvent>.empty());
      return TaskListBloc(repository: repository, taskBloc: taskBloc);
    },
    act: (bloc) async {
      bloc.add(const TaskListStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(TaskListTaskEventReceived(
          domain_event.TaskEvent(type: domain_event.TaskEventType.created, task: task)));
    },
    expect: () => [
      const TaskListState(status: TaskListStatus.loading),
      const TaskListState(status: TaskListStatus.success, tasks: []),
      TaskListState(status: TaskListStatus.success, tasks: [task]),
    ],
    verify: (_) {
      verify(
        () => taskBloc.add(
          any(that: isA<task_bloc_event.TaskCreated>()),
        ),
      ).called(1);
    },
  );

  blocTest<TaskListBloc, TaskListState>(
    're-syncs reminders when socket task event updates pending tasks',
    build: () {
      when(() => repository.fetchTasks(familyId: any(named: 'familyId')))
          .thenAnswer((_) async => []);
      when(() => repository.subscribeToTaskEvents(familyId: any(named: 'familyId')))
          .thenAnswer((_) => const Stream<domain_event.TaskEvent>.empty());
      return TaskListBloc(repository: repository, taskBloc: taskBloc);
    },
    act: (bloc) async {
      bloc.add(const TaskListStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(
        TaskListTaskEventReceived(
          domain_event.TaskEvent(
            type: domain_event.TaskEventType.updated,
            task: _dueTask,
          ),
        ),
      );
    },
    expect: () => [
      const TaskListState(status: TaskListStatus.loading),
      const TaskListState(status: TaskListStatus.success, tasks: []),
      TaskListState(status: TaskListStatus.success, tasks: [_dueTask]),
    ],
    verify: (_) {
      verify(
        () => taskBloc.add(
          any(that: isA<task_bloc_event.TaskRemindersSynced>()),
        ),
      ).called(1);
    },
  );

  blocTest<TaskListBloc, TaskListState>(
    'ignores events for different families when familyId is set',
    build: () {
      when(() => repository.fetchTasks(familyId: any(named: 'familyId')))
          .thenAnswer((_) async => []);
      when(() => repository.subscribeToTaskEvents(familyId: any(named: 'familyId')))
          .thenAnswer((_) => const Stream<domain_event.TaskEvent>.empty());
      return TaskListBloc(
        repository: repository,
        taskBloc: taskBloc,
        familyId: 'family-1',
      );
    },
    act: (bloc) async {
      bloc.add(const TaskListStarted());
      await Future<void>.delayed(Duration.zero);
      final otherFamilyTask = task.copyWith(familyId: 'family-2');
      bloc.add(
        TaskListTaskEventReceived(
          domain_event.TaskEvent(
            type: domain_event.TaskEventType.created,
            task: otherFamilyTask,
            familyId: 'family-2',
          ),
        ),
      );
    },
    expect: () => const [
      TaskListState(status: TaskListStatus.loading),
      TaskListState(status: TaskListStatus.success, tasks: []),
    ],
    verify: (_) {
      verifyNever(
        () => taskBloc.add(
          any(that: isA<task_bloc_event.TaskCreated>()),
        ),
      );
    },
  );
}
