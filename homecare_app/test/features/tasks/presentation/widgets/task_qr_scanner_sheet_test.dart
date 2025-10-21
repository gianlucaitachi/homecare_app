import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/core/di/service_locator.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_event.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_state.dart';
import 'package:homecare_app/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:homecare_app/features/tasks/presentation/widgets/task_qr_scanner_sheet.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';

class _MockTaskRepository extends Mock implements TaskRepository {}

class _MockTaskBloc extends MockBloc<TaskEvent, TaskState> implements TaskBloc {}

class _FakeTaskEvent extends Fake implements TaskEvent {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeTaskEvent());
  });

  setUp(() async {
    await sl.reset();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('scanner sheet stays open on failure and closes after success',
      (tester) async {
    final repository = _MockTaskRepository();
    final taskBloc = _MockTaskBloc();

    when(() => taskBloc.state).thenReturn(const TaskState());
    when(() => taskBloc.stream).thenAnswer((_) => const Stream.empty());
    when(taskBloc.close).thenAnswer((_) async {});
    when(() => taskBloc.add(any())).thenReturn(null);

    sl.registerLazySingleton<TaskRepository>(() => repository);

    final task = Task(
      id: 'task-42',
      familyId: 'family-7',
      title: 'Morning walk',
      description: 'Assist with a 20-minute walk',
      status: TaskStatus.pending,
      dueDate: DateTime(2024, 7, 1),
      assignedUserId: 'caregiver-3',
      qrPayload: 'payload-123',
      qrImageBase64: 'image-data',
      createdAt: DateTime(2024, 6, 1),
      updatedAt: DateTime(2024, 6, 1),
      completedAt: null,
    );

    final completedTask = task.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime(2024, 7, 1, 9),
    );

    when(() => repository.fetchTask(task.id)).thenAnswer((_) async => task);

    var callCount = 0;
    when(() => repository.completeTaskByQrPayload(task.qrPayload)).thenAnswer(
      (_) async {
        callCount++;
        if (callCount == 1) {
          throw Exception('network down');
        }
        return completedTask;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<TaskBloc>.value(
            value: taskBloc,
            child: TaskDetailScreen(taskId: task.id),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Scan QR to complete'), findsOneWidget);

    await tester.tap(find.text('Scan QR to complete'));
    await tester.pumpAndSettle();

    final scannerFinder = find.byType(MobileScanner);
    expect(scannerFinder, findsOneWidget);

    Future<void> triggerScan() async {
      final scanner = tester.widget<MobileScanner>(scannerFinder);
      final onDetect = scanner.onDetect;
      expect(onDetect, isNotNull);
      onDetect!(BarcodeCapture(barcodes: [Barcode(rawValue: task.qrPayload)]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    await triggerScan();

    expect(callCount, 1);
    expect(find.byType(TaskQrScannerSheet), findsOneWidget);
    expect(find.textContaining('network down'), findsWidgets);

    await triggerScan();

    expect(callCount, 2);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TaskQrScannerSheet), findsNothing);
  });
}
