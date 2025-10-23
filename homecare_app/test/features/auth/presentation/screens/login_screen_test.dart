import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/core/di/service_locator.dart';
import 'package:homecare_app/core/notifications/notification_service.dart';
import 'package:homecare_app/core/socket/socket_service.dart';
import 'package:homecare_app/features/app_shell/presentation/authenticated_shell.dart';
import 'package:homecare_app/features/auth/domain/entities/auth_session.dart';
import 'package:homecare_app/features/auth/domain/entities/user.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart'
    show AuthBloc, AuthState, Authenticated, Unauthenticated;
import 'package:homecare_app/features/auth/presentation/screens/login_screen.dart';
import 'package:homecare_app/features/chat/data/models/chat_message.dart';
import 'package:homecare_app/features/chat/data/repositories/chat_repository.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/entities/task_event.dart' as domain;
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_auth_bloc.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

class MockChatRepository extends Mock implements ChatRepository {}

class MockSocketService extends Mock implements SocketService {}

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthBloc mockAuthBloc;
  late MockTaskRepository mockTaskRepository;
  late MockChatRepository mockChatRepository;
  late MockSocketService mockSocketService;
  late MockNotificationService mockNotificationService;

  setUpAll(() {
    registerAuthFallbackValues();
  });

  setUp(() async {
    await sl.reset();

    mockAuthBloc = MockAuthBloc();
    mockTaskRepository = MockTaskRepository();
    mockChatRepository = MockChatRepository();
    mockSocketService = MockSocketService();
    mockNotificationService = MockNotificationService();

    when(() => mockTaskRepository.fetchTasks(familyId: any(named: 'familyId')))
        .thenAnswer((_) async => <Task>[]);
    when(() => mockTaskRepository.subscribeToTaskEvents(
          familyId: any(named: 'familyId'),
        )).thenAnswer((_) => const Stream<domain.TaskEvent>.empty());
    when(() => mockTaskRepository.close()).thenAnswer((_) async {});

    when(() => mockChatRepository.fetchMessages(any()))
        .thenAnswer((_) async => <ChatMessage>[]);

    when(() => mockSocketService.chatMessages)
        .thenAnswer((_) => const Stream<Map<String, dynamic>>.empty());
    when(() => mockSocketService.connect(any()))
        .thenAnswer((_) async {});
    when(() => mockSocketService.joinRoom(any())).thenReturn(null);
    when(
      () => mockSocketService.sendChatMessage(
        familyId: any(named: 'familyId'),
        senderId: any(named: 'senderId'),
        content: any(named: 'content'),
      ),
    ).thenReturn(null);

    when(() => mockNotificationService.scheduleTaskReminder(
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          dueDate: any(named: 'dueDate'),
        )).thenAnswer((_) async {});
    when(() => mockNotificationService.updateTaskReminder(
          taskId: any(named: 'taskId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          dueDate: any(named: 'dueDate'),
        )).thenAnswer((_) async {});
    when(() => mockNotificationService.cancelTaskReminder(any()))
        .thenAnswer((_) async {});
    when(() => mockNotificationService.cancelAllReminders())
        .thenAnswer((_) async {});

    sl
      ..registerLazySingleton<TaskRepository>(() => mockTaskRepository)
      ..registerLazySingleton<ChatRepository>(() => mockChatRepository)
      ..registerLazySingleton<SocketService>(() => mockSocketService)
      ..registerLazySingleton<NotificationService>(() => mockNotificationService);
  });

  tearDown(() async {
    await mockAuthBloc.close();
    await sl.reset();
  });

  Widget buildScreen() {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: const LoginScreen(),
      ),
    );
  }

  testWidgets('navigates to AuthenticatedShell when Authenticated state emitted',
      (tester) async {
    const user = User(
      id: 'user-1',
      name: 'Test User',
      email: 'test@example.com',
      familyId: 'family-1',
    );
    const session = AuthSession(
      user: user,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );
    const initialState = Unauthenticated();
    const authenticatedState = Authenticated(session);

    when(() => mockAuthBloc.state).thenReturn(initialState);
    whenListen(
      mockAuthBloc,
      Stream<AuthState>.fromIterable(
        const [initialState, authenticatedState],
      ),
      initialState: initialState,
    );

    await tester.pumpWidget(buildScreen());
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(AuthenticatedShell), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
