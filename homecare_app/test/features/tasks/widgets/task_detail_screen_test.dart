import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/core/di/service_locator.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/entities/task_event.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:homecare_app/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:homecare_app/features/tasks/presentation/widgets/task_qr_view.dart';

class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository()
      : _task = Task(
          id: 'task-1',
          familyId: 'family-1',
          title: 'Daily exercise',
          description: 'Assist patient with 20 minutes of stretching',
          status: TaskStatus.pending,
          dueDate: DateTime(2024, 1, 2),
          assignedUserId: 'caregiver-1',
          qrPayload: 'payload-1',
          qrImageBase64: 'data:image/png;base64,aGVsbG8=',
          createdAt: DateTime(2024, 1, 1, 8),
          updatedAt: DateTime(2024, 1, 1, 8),
          completedAt: null,
        );

  Task _task;

  @override
  Future<Task> assignTask(String id, String userId) async {
    _task = _task.copyWith(assignedUserId: userId, status: TaskStatus.inProgress);
    return _task;
  }

  @override
  Future<Task> completeTaskByQrPayload(String payload) async {
    _task = _task.copyWith(status: TaskStatus.completed, completedAt: DateTime.now());
    return _task;
  }

  @override
  Future<Task> createTask({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  }) async => _task;

  @override
  Future<void> deleteTask(String id) async {}

  @override
  Future<Task> fetchTask(String id) async => _task;

  @override
  Future<List<Task>> fetchTasks({String? familyId}) async => [_task];

  @override
  Stream<TaskEvent> subscribeToTaskEvents({String? familyId}) => const Stream.empty();

  @override
  Future<Task> updateTask(
    String id, {
    String? title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
    TaskStatus? status,
  }) async => _task;

  @override
  Future<void> close() async {}
}

void main() {
  setUp(() async {
    await sl.reset();
    sl.registerLazySingleton<TaskRepository>(() => _FakeTaskRepository());
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('shows task detail information and QR scanner sheet', (tester) async {
    final repository = sl<TaskRepository>() as _FakeTaskRepository;
    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailScreen(taskId: repository._task.id),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Task QR Code'), findsOneWidget);
    expect(find.byType(TaskQrView), findsOneWidget);

    await tester.tap(find.text('Scan QR to complete'));
    await tester.pumpAndSettle();

    expect(find.text('Scan task QR code'), findsOneWidget);
  });
}
