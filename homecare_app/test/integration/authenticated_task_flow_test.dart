import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homecare_app/core/api/api_client.dart';
import 'package:homecare_app/core/constants/storage_keys.dart';
import 'package:homecare_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:homecare_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:homecare_app/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:homecare_app/features/chat/data/models/chat_message.dart';
import 'package:homecare_app/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Authenticated task flow', () {
    late _MockSecureStorage secureStorage;
    late ApiClient apiClient;
    late AuthRepositoryImpl authRepository;
    late AuthRemoteDataSourceImpl authRemoteDataSource;
    late TaskRemoteDataSource taskRemoteDataSource;
    late ChatRemoteDataSource chatRemoteDataSource;
    late _FakeServerAdapter fakeServer;
    late Map<String, String?> storage;

    setUp(() {
      secureStorage = _MockSecureStorage();
      storage = <String, String?>{};

      when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        return storage[key];
      });
      when(() => secureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        final value = invocation.namedArguments[#value] as String?;
        if (value == null) {
          storage.remove(key);
        } else {
          storage[key] = value;
        }
      });
      when(() => secureStorage.delete(key: any(named: 'key'))).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        storage.remove(key);
      });
      when(() => secureStorage.deleteAll()).thenAnswer((_) async {
        storage.clear();
      });

      apiClient = ApiClient('https://example.com/api', secureStorage);
      fakeServer = _FakeServerAdapter();
      apiClient.httpClientAdapter = fakeServer;

      authRemoteDataSource = AuthRemoteDataSourceImpl(apiClient: apiClient);
      authRepository = AuthRepositoryImpl(
        remoteDataSource: authRemoteDataSource,
        secureStorage: secureStorage,
      );
      taskRemoteDataSource = TaskRemoteDataSourceImpl(apiClient: apiClient);
      chatRemoteDataSource = ChatRemoteDataSource(apiClient: apiClient);
    });

    testWidgets('logs in and performs authenticated task and chat requests', (tester) async {
      await authRepository.login(email: 'alice@example.com', password: 'secret');

      final tasks = await taskRemoteDataSource.fetchTasks();
      expect(tasks, hasLength(1));
      expect(tasks.single.status, TaskStatus.pending);

      final createdTask = await taskRemoteDataSource.createTask(
        familyId: 'family-1',
        title: 'New task',
      );

      expect(createdTask.id, equals('task-2'));
      expect(createdTask.title, equals('New task'));

      final messages = await chatRemoteDataSource.fetchMessages('family-1');
      expect(messages, hasLength(1));
      expect(messages.single, isA<ChatMessage>());
      expect(messages.single.content, equals('Hello from the family chat!'));

      expect(fakeServer.unauthorizedCount, equals(1));
      expect(fakeServer.fetchSuccessCount, equals(1));
      expect(fakeServer.createSuccessCount, equals(1));
      expect(fakeServer.messagesSuccessCount, equals(1));
      expect(storage[StorageKeys.accessToken], equals(_FakeServerAdapter.refreshedAccessToken));
      expect(storage[StorageKeys.refreshToken], equals(_FakeServerAdapter.refreshedRefreshToken));
    });
  });
}

class _FakeServerAdapter extends HttpClientAdapter {
  static const initialAccessToken = 'initial-access';
  static const initialRefreshToken = 'initial-refresh';
  static const refreshedAccessToken = 'refreshed-access';
  static const refreshedRefreshToken = 'refreshed-refresh';

  int unauthorizedCount = 0;
  int fetchSuccessCount = 0;
  int createSuccessCount = 0;
  int messagesSuccessCount = 0;
  bool _hasSentUnauthorizedForFetch = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future? cancelFuture) async {
    final path = options.uri.path;

    if (options.method == 'POST' && path == '/api/auth/login') {
      return ResponseBody.fromString(
        jsonEncode({
          'accessToken': initialAccessToken,
          'refreshToken': initialRefreshToken,
          'user': {'id': 'user-1', 'name': 'Alice'},
        }),
        200,
        headers: _jsonHeaders,
      );
    }

    if (options.method == 'POST' && path == '/api/auth/refresh') {
      return ResponseBody.fromString(
        jsonEncode({
          'accessToken': refreshedAccessToken,
          'refreshToken': refreshedRefreshToken,
        }),
        200,
        headers: _jsonHeaders,
      );
    }

    if (path == '/api/tasks' && options.method == 'GET') {
      final authHeader = options.headers['Authorization'] as String?;
      if (!_hasSentUnauthorizedForFetch && authHeader == 'Bearer $initialAccessToken') {
        _hasSentUnauthorizedForFetch = true;
        unauthorizedCount += 1;
        return ResponseBody.fromString('Unauthorized', 401, headers: _jsonHeaders);
      }

      if (authHeader == 'Bearer $refreshedAccessToken') {
        fetchSuccessCount += 1;
        return ResponseBody.fromString(
          jsonEncode({'tasks': [_taskJson]}),
          200,
          headers: _jsonHeaders,
        );
      }

      unauthorizedCount += 1;
      return ResponseBody.fromString('Unauthorized', 401, headers: _jsonHeaders);
    }

    if (path == '/api/tasks' && options.method == 'POST') {
      final authHeader = options.headers['Authorization'] as String?;
      if (authHeader != 'Bearer $refreshedAccessToken') {
        unauthorizedCount += 1;
        return ResponseBody.fromString('Unauthorized', 401, headers: _jsonHeaders);
      }

      createSuccessCount += 1;
      return ResponseBody.fromString(
        jsonEncode({'task': _createdTaskJson(options.data)}),
        201,
        headers: _jsonHeaders,
      );
    }

    if (path == '/api/families/family-1/messages' && options.method == 'GET') {
      final authHeader = options.headers['Authorization'] as String?;
      if (authHeader != 'Bearer $refreshedAccessToken') {
        unauthorizedCount += 1;
        return ResponseBody.fromString('Unauthorized', 401, headers: _jsonHeaders);
      }

      messagesSuccessCount += 1;
      return ResponseBody.fromString(
        jsonEncode({'messages': [_messageJson]}),
        200,
        headers: _jsonHeaders,
      );
    }

    return ResponseBody.fromString('Not Found', 404, headers: _jsonHeaders);
  }

  Map<String, List<String>> get _jsonHeaders => {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      };

  static Map<String, dynamic> get _taskJson {
    const timestamp = '2024-01-01T12:00:00.000Z';
    return {
      'id': 'task-1',
      'familyId': 'family-1',
      'title': 'Sample task',
      'description': null,
      'status': 'pending',
      'dueDate': null,
      'assignedUserId': null,
      'qrPayload': 'payload-1',
      'qrImageBase64': 'qr-image-1',
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'completedAt': null,
    };
  }

  static Map<String, dynamic> _createdTaskJson(dynamic requestData) {
    const timestamp = '2024-01-01T13:00:00.000Z';
    final payload = Map<String, dynamic>.from(requestData as Map);
    return {
      'id': 'task-2',
      'familyId': payload['familyId'] as String? ?? 'family-1',
      'title': payload['title'] as String? ?? 'Untitled',
      'description': payload['description'],
      'status': 'pending',
      'dueDate': payload['dueDate'],
      'assignedUserId': payload['assignedUserId'],
      'qrPayload': 'payload-2',
      'qrImageBase64': 'qr-image-2',
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'completedAt': null,
    };
  }

  static Map<String, dynamic> get _messageJson {
    const timestamp = '2024-01-02T09:30:00.000Z';
    return {
      'id': 'message-1',
      'familyId': 'family-1',
      'senderId': 'user-1',
      'content': 'Hello from the family chat!',
      'createdAt': timestamp,
    };
  }
}
