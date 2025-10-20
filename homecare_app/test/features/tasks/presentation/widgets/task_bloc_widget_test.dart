import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/core/notifications/notification_service.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_event.dart';
import 'package:mocktail/mocktail.dart';

class _MockNotificationService extends Mock implements NotificationService {}

void main() {
  late _MockNotificationService notificationService;
  late Task task;
  late TaskBloc bloc;

  setUp(() {
    notificationService = _MockNotificationService();
    task = Task(
      id: 'widget-task',
      title: 'Widget Test Task',
      description: 'Verify widget interactions trigger scheduling.',
      dueDate: DateTime.now().add(const Duration(days: 1)),
    );

    when(() => notificationService.scheduleTaskReminder(
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          dueDate: any(named: 'dueDate'),
        )).thenAnswer((_) async {});
    when(() => notificationService.cancelTaskReminder(any()))
        .thenAnswer((_) async {});
    bloc = TaskBloc(notificationService: notificationService);
  });

  tearDown(() async {
    await bloc.close();
  });

  testWidgets('tapping the create button schedules a task reminder',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      context.read<TaskBloc>().add(TaskCreated(task));
                    },
                    child: const Text('Create Task'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Create Task'));
    await tester.pump();

    verify(() => notificationService.scheduleTaskReminder(
          taskId: task.id,
          title: task.title,
          body: task.description!,
          dueDate: any(named: 'dueDate'),
        )).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
