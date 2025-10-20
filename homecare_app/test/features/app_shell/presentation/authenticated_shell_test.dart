import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/core/di/service_locator.dart';
import 'package:homecare_app/core/socket/socket_service.dart';
import 'package:homecare_app/features/app_shell/presentation/authenticated_shell.dart';
import 'package:homecare_app/features/auth/domain/entities/auth_session.dart';
import 'package:homecare_app/features/auth/domain/entities/user.dart';
import 'package:homecare_app/features/chat/data/models/chat_message.dart';
import 'package:homecare_app/features/chat/data/repositories/chat_repository.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/entities/task_event.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:mocktail/mocktail.dart';

class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository({required List<Task> initialTasks})
      : _tasks = List<Task>.from(initialTasks);

  final List<Task> _tasks;
  final _eventsController = StreamController<TaskEvent>.broadcast();
  int _generated = 0;

  @override
  Future<Task> assignTask(String id, String userId) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) throw StateError('Task not found');
    final updated = _tasks[index].copyWith(
      assignedUserId: userId,
      updatedAt: DateTime.now(),
    );
    _tasks[index] = updated;
    _eventsController.add(TaskEvent(type: TaskEventType.assigned, task: updated));
    return updated;
  }

  @override
  Future<Task> completeTaskByQrPayload(String payload) async {
    final index = _tasks.indexWhere((task) => task.qrPayload == payload);
    if (index == -1) throw StateError('Task not found');
    final updated = _tasks[index].copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _tasks[index] = updated;
    _eventsController.add(TaskEvent(type: TaskEventType.completed, task: updated));
    return updated;
  }

  @override
  Future<Task> createTask({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  }) async {
    final now = DateTime.now();
    final task = Task(
      id: 'generated-${_generated++}',
      familyId: familyId,
      title: title,
      description: description,
      status: TaskStatus.pending,
      dueDate: dueDate,
      assignedUserId: assignedUserId,
      qrPayload: 'generated-$familyId',
      qrImageBase64: 'data:image/png;base64,AA==',
      createdAt: now,
      updatedAt: now,
      completedAt: null,
    );
    _tasks.add(task);
    _eventsController.add(TaskEvent(type: TaskEventType.created, task: task));
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((task) => task.id == id);
    _eventsController.add(TaskEvent(type: TaskEventType.deleted, taskId: id));
  }

  @override
  Future<Task> fetchTask(String id) async {
    return _tasks.firstWhere((task) => task.id == id);
  }

  @override
  Future<List<Task>> fetchTasks({String? familyId}) async {
    if (familyId == null) {
      return List<Task>.from(_tasks);
    }
    return _tasks.where((task) => task.familyId == familyId).toList();
  }

  @override
  Stream<TaskEvent> subscribeToTaskEvents({String? familyId}) {
    return _eventsController.stream;
  }

  @override
  Future<Task> updateTask(
    String id, {
    String? title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
    TaskStatus? status,
  }) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) throw StateError('Task not found');
    final updated = _tasks[index].copyWith(
      title: title,
      description: description,
      dueDate: dueDate,
      assignedUserId: assignedUserId,
      status: status,
      updatedAt: DateTime.now(),
    );
    _tasks[index] = updated;
    _eventsController.add(TaskEvent(type: TaskEventType.updated, task: updated));
    return updated;
  }

  @override
  Future<void> close() async {
    await _eventsController.close();
  }
}

class MockChatRepository extends Mock implements ChatRepository {}

class MockSocketService extends Mock implements SocketService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final user = User(
    id: 'user-1',
    name: 'Alex Johnson',
    email: 'alex@example.com',
    familyId: 'family-123',
  );
  final session = AuthSession(
    user: user,
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );
  final sampleTask = Task(
    id: 'task-1',
    familyId: user.familyId,
    title: 'Prepare medication',
    description: 'Morning pills for grandma',
    status: TaskStatus.pending,
    dueDate: DateTime(2024, 10, 1),
    assignedUserId: 'nurse-7',
    qrPayload: 'task-1-qr',
    qrImageBase64: 'data:image/png;base64,AA==',
    createdAt: DateTime(2024, 9, 28),
    updatedAt: DateTime(2024, 9, 28),
    completedAt: null,
  );
  final initialMessage = ChatMessage(
    id: 'msg-1',
    familyId: user.familyId,
    senderId: 'nurse-7',
    content: 'Vitals look great today!',
    createdAt: DateTime.now(),
  );

  late InMemoryTaskRepository taskRepository;
  late MockChatRepository chatRepository;
  late MockSocketService socketService;
  late StreamController<Map<String, dynamic>> chatStreamController;

  setUp(() async {
    await sl.reset();
    taskRepository = InMemoryTaskRepository(initialTasks: [sampleTask]);
    chatRepository = MockChatRepository();
    socketService = MockSocketService();
    chatStreamController = StreamController<Map<String, dynamic>>.broadcast();

    sl
      ..registerLazySingleton<TaskRepository>(() => taskRepository)
      ..registerLazySingleton<ChatRepository>(() => chatRepository)
      ..registerLazySingleton<SocketService>(() => socketService);

    when(() => socketService.connect(any())).thenAnswer((_) async {});
    when(() => socketService.joinRoom(any())).thenAnswer((_) {});
    when(() => socketService.chatMessages)
        .thenAnswer((_) => chatStreamController.stream);
    when(() => socketService.sendChatMessage(
          familyId: any(named: 'familyId'),
          senderId: any(named: 'senderId'),
          content: any(named: 'content'),
        )).thenAnswer((invocation) {
      final familyId = invocation.namedArguments[#familyId] as String;
      final senderId = invocation.namedArguments[#senderId] as String;
      final content = invocation.namedArguments[#content] as String;
      chatStreamController.add({
        'id': 'stream-${DateTime.now().microsecondsSinceEpoch}',
        'familyId': familyId,
        'senderId': senderId,
        'content': content,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });

    when(() => chatRepository.fetchMessages(any()))
        .thenAnswer((_) async => [initialMessage]);
  });

  tearDown(() async {
    await chatStreamController.close();
    await taskRepository.close();
    await sl.reset();
  });

  testWidgets('navigates from tasks list to detail and task form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedShell(session: session),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Prepare medication'), findsOneWidget);

    await tester.tap(find.text('Prepare medication'));
    await tester.pumpAndSettle();

    expect(find.text('Task QR Code'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Create task'), findsOneWidget);
  });

  testWidgets('loads chat history and sends new messages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedShell(session: session),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.text('Family Chat'), findsOneWidget);
    expect(find.text('Vitals look great today!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'On my way with supplies');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('On my way with supplies'), findsOneWidget);

    chatStreamController.add({
      'id': 'stream-update',
      'familyId': user.familyId,
      'senderId': 'coordinator-5',
      'content': 'Can we confirm the evening visit?',
      'createdAt': DateTime.now().toIso8601String(),
    });
    await tester.pump();

    expect(find.text('Can we confirm the evening visit?'), findsOneWidget);
  });
}
