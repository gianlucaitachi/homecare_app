import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/core/notifications/notification_service.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart'
    as domain;
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_event.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_state.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationService extends Mock implements NotificationService {}

void main() {
  late _MockNotificationService notificationService;
  late domain.Task taskWithDueDate;
  late DateTime baseTime;

  setUp(() {
    notificationService = _MockNotificationService();
    baseTime = DateTime(2024, 1, 1, 9);
    taskWithDueDate = domain.Task(
      id: '1',
      familyId: 'family-1',
      title: 'Test Task',
      description: 'Remember to finish testing.',
      status: domain.TaskStatus.pending,
      dueDate: baseTime.add(const Duration(hours: 6)),
      qrPayload: 'qr-payload',
      qrImageBase64: 'qr-image',
      createdAt: baseTime,
      updatedAt: baseTime,
    );

    when(() => notificationService.scheduleTaskReminder(
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          dueDate: any(named: 'dueDate'),
        )).thenAnswer((_) async {});
    when(() => notificationService.updateTaskReminder(
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          dueDate: any(named: 'dueDate'),
        )).thenAnswer((_) async {});
    when(() => notificationService.cancelTaskReminder(any()))
        .thenAnswer((_) async {});
  });

  blocTest<TaskBloc, TaskState>(
    'schedules reminder when a task with due date is created',
    build: () => TaskBloc(notificationService: notificationService),
    act: (bloc) => bloc.add(TaskCreated(taskWithDueDate)),
    expect: () => [
      const TaskState(status: TaskViewStatus.loading),
      TaskState(
        status: TaskViewStatus.success,
        task: taskWithDueDate,
        operation: TaskOperation.create,
      ),
    ],
    verify: (_) {
      verify(() => notificationService.scheduleTaskReminder(
            taskId: taskWithDueDate.id,
            title: taskWithDueDate.title,
            body: taskWithDueDate.description!,
            dueDate: any(named: 'dueDate'),
          )).called(1);
    },
  );

  blocTest<TaskBloc, TaskState>(
    'updates reminder when task due date changes',
    build: () => TaskBloc(notificationService: notificationService),
    act: (bloc) {
      final updated = taskWithDueDate.copyWith(
        dueDate: taskWithDueDate.dueDate!.add(const Duration(hours: 2)),
      );
      bloc
        ..add(TaskCreated(taskWithDueDate))
        ..add(TaskUpdated(previousTask: taskWithDueDate, updatedTask: updated));
    },
    expect: () => [
      const TaskState(status: TaskViewStatus.loading),
      TaskState(
        status: TaskViewStatus.success,
        task: taskWithDueDate,
        operation: TaskOperation.create,
      ),
      const TaskState(status: TaskViewStatus.loading),
      TaskState(
        status: TaskViewStatus.success,
        task: taskWithDueDate.copyWith(
          dueDate: taskWithDueDate.dueDate!.add(const Duration(hours: 2)),
        ),
        operation: TaskOperation.update,
      ),
    ],
    verify: (_) {
      verify(() => notificationService.updateTaskReminder(
            taskId: taskWithDueDate.id,
            title: taskWithDueDate.title,
            body: taskWithDueDate.description!,
            dueDate: any(named: 'dueDate'),
          )).called(1);
    },
  );

  blocTest<TaskBloc, TaskState>(
    'cancels reminder when due date is removed',
    build: () => TaskBloc(notificationService: notificationService),
    act: (bloc) {
      bloc
        ..add(TaskCreated(taskWithDueDate))
        ..add(
          TaskUpdated(
            previousTask: taskWithDueDate,
            updatedTask: taskWithDueDate.copyWith(dueDate: null),
          ),
        );
    },
    expect: () => [
      const TaskState(status: TaskViewStatus.loading),
      TaskState(
        status: TaskViewStatus.success,
        task: taskWithDueDate,
        operation: TaskOperation.create,
      ),
      const TaskState(status: TaskViewStatus.loading),
      TaskState(
        status: TaskViewStatus.success,
        task: taskWithDueDate.copyWith(dueDate: null),
        operation: TaskOperation.update,
      ),
    ],
    verify: (_) {
      verify(() => notificationService.cancelTaskReminder(taskWithDueDate.id))
          .called(1);
    },
  );

  blocTest<TaskBloc, TaskState>(
    'cancels reminder when task is marked completed',
    build: () => TaskBloc(notificationService: notificationService),
    act: (bloc) {
      final completedTask = taskWithDueDate.copyWith(
        status: domain.TaskStatus.completed,
        completedAt: taskWithDueDate.dueDate,
        updatedAt: taskWithDueDate.updatedAt.add(const Duration(minutes: 5)),
      );
      bloc
        ..add(TaskCreated(taskWithDueDate))
        ..add(
          TaskUpdated(
            previousTask: taskWithDueDate,
            updatedTask: completedTask,
          ),
        );
    },
    expect: () => [
      const TaskState(status: TaskViewStatus.loading),
      TaskState(
        status: TaskViewStatus.success,
        task: taskWithDueDate,
        operation: TaskOperation.create,
      ),
      const TaskState(status: TaskViewStatus.loading),
      TaskState(
        status: TaskViewStatus.success,
        task: taskWithDueDate.copyWith(
          status: domain.TaskStatus.completed,
          completedAt: taskWithDueDate.dueDate,
          updatedAt: taskWithDueDate.updatedAt.add(
            const Duration(minutes: 5),
          ),
        ),
        operation: TaskOperation.update,
      ),
    ],
    verify: (_) {
      verify(() => notificationService.cancelTaskReminder(taskWithDueDate.id))
          .called(1);
    },
  );

  blocTest<TaskBloc, TaskState>(
    'cancels reminder when task is deleted',
    build: () => TaskBloc(notificationService: notificationService),
    act: (bloc) {
      bloc
        ..add(TaskCreated(taskWithDueDate))
        ..add(TaskDeleted(taskWithDueDate));
    },
    expect: () => [
      const TaskState(status: TaskViewStatus.loading),
      TaskState(
        status: TaskViewStatus.success,
        task: taskWithDueDate,
        operation: TaskOperation.create,
      ),
      const TaskState(status: TaskViewStatus.loading),
      TaskState(
        status: TaskViewStatus.success,
        task: taskWithDueDate,
        operation: TaskOperation.delete,
      ),
    ],
    verify: (_) {
      verify(() => notificationService.cancelTaskReminder(taskWithDueDate.id))
          .called(greaterThanOrEqualTo(1));
    },
  );

  blocTest<TaskBloc, TaskState>(
    'schedules reminders when syncing pending tasks',
    build: () => TaskBloc(notificationService: notificationService),
    act: (bloc) {
      final anotherTask = taskWithDueDate.copyWith(
        id: '2',
        title: 'Another Task',
        dueDate: taskWithDueDate.dueDate!.add(const Duration(hours: 1)),
      );
      bloc.add(TaskRemindersSynced([taskWithDueDate, anotherTask]));
    },
    expect: () => <TaskState>[],
    verify: (_) {
      verify(() => notificationService.scheduleTaskReminder(
            taskId: any(named: 'taskId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            dueDate: any(named: 'dueDate'),
          )).called(2);
    },
  );
}
