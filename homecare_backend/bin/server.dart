import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:homecare_backend/controllers/auth_controller.dart';
import 'package:homecare_backend/controllers/chat_controller.dart';
import 'package:homecare_backend/controllers/task_controller.dart';
import 'package:homecare_backend/db/database.dart';
import 'package:homecare_backend/middleware/authentication_middleware.dart';
import 'package:homecare_backend/middleware/authorization_context_middleware.dart';
import 'package:homecare_backend/repositories/message_repository.dart';
import 'package:homecare_backend/repositories/task_repository.dart';
import 'package:homecare_backend/repositories/user_repository.dart';
import 'package:homecare_backend/services/jwt_service.dart';
import 'package:homecare_backend/services/socket_service.dart';
import 'package:homecare_backend/services/task_event_hub.dart';

Future<void> main(List<String> args) async {
  // 1. Khởi tạo kết nối CSDL
  final dbClient = PostgresClient.fromEnv();
  await dbClient.connect();

  // 2. Khởi tạo các Repository
  final userRepository = PostgresUserRepository(dbClient);
  final taskRepository = PostgresTaskRepository(dbClient);
  final messageRepository = PostgresMessageRepository(dbClient);

  // 4. Khởi tạo các Controller với Repository tương ứng
  final jwtService = JwtService();

  final authController = AuthController(
    userRepository,
    jwtService: jwtService,
  );
  final taskEventHub = TaskEventHub();
  final taskController = TaskController(taskRepository, taskEventHub);
  final socketAdapter = SocketIOServerAdapter();
  final socketService =
      SocketService(server: socketAdapter, messageRepository: messageRepository);
  final chatController = ChatController(messageRepository, socketService);

  // 5. Thiết lập các routes
  final app = Router();
  final apiRouter = Router();
  apiRouter.get('/health', (Request request) {
    return Response.ok(jsonEncode({'status': 'ok'}));
  });

  final authRouter = Router()
    ..post('/register', authController.register)
    ..post('/login', authController.login)
    ..post('/refresh', authController.refresh)
    ..post('/logout', authController.logout);
  apiRouter.mount('/auth', authRouter);

  final meRouter = Router()..get('/', authController.me);

  final familiesRouter = Router()
    ..get('/<familyId>/messages', chatController.getMessages)
    ..post('/<familyId>/messages', chatController.postMessage)
    ..get('/<familyId>/messages/ws', chatController.connectWebSocket);
  final protectedFamiliesHandler = _protectedHandler(
    jwtService,
    userRepository,
    familiesRouter,
  );

  final protectedTasksHandler = _protectedHandler(
    jwtService,
    userRepository,
    taskController.router,
  );

  final protectedMeHandler = _protectedHandler(
    jwtService,
    userRepository,
    meRouter,
  );

  apiRouter.mount('/families', protectedFamiliesHandler);
  apiRouter.mount('/tasks', protectedTasksHandler);
  apiRouter.mount('/me', protectedMeHandler);
  app.mount('/api', apiRouter);

  socketService.initialize();

  final handler = Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addMiddleware(_jsonResponseMiddleware())
      .addHandler(app);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  socketService.attachToHttpServer(server);
  print('Server listening on port $port');
}

Handler _protectedHandler(
  JwtService jwtService,
  UserRepository userRepository,
  Handler protectedHandler,
) {
  return Pipeline()
      .addMiddleware(authenticationMiddleware(jwtService))
      .addMiddleware(authorizationContextMiddleware(userRepository))
      .addHandler(protectedHandler);
}

// Middleware để mặc định các response là JSON
Middleware _jsonResponseMiddleware() {
  return (innerHandler) {
    return (request) async {
      final response = await innerHandler(request);
      // Chỉ thêm header nếu nó chưa được thiết lập
      if (!response.headers.containsKey('content-type')) {
        return response.change(headers: {'content-type': 'application/json'});
      }
      return response;
    };
  };
}

