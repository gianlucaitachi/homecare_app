import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:homecare_backend/controllers/auth_controller.dart';
import 'package:homecare_backend/controllers/chat_controller.dart';
import 'package:homecare_backend/controllers/task_controller.dart';
import 'package:homecare_backend/db/postgres_client.dart';
import 'package:homecare_backend/repositories/message_repository.dart';
import 'package:homecare_backend/repositories/user_repository.dart';
import 'package:homecare_backend/services/socket_service.dart';

Future<void> main(List<String> args) async {
  // 1. Khởi tạo kết nối CSDL
  final dbClient = PostgresClient.fromEnv();
  await dbClient.connect();

  // 2. Khởi tạo các Repository
  final userRepository = PostgresUserRepository(dbClient);
  final messageRepository = PostgresMessageRepository(dbClient);

  // 3. Khởi tạo Socket service
  final socketAdapter = SocketIOServerAdapter();
  final socketService = SocketService(
    server: socketAdapter,
    messageRepository: messageRepository,
  );
  socketService.initialize();

  // 4. Khởi tạo các Controller với Repository tương ứng
  final authController = AuthController(userRepository);
  final chatController = ChatController(messageRepository, socketService);
  final taskController = TaskController(socketService);

  // 5. Thiết lập các routes
  final app = Router();
  app.post('/auth/register', authController.register);
  app.post('/auth/login', authController.login);
  app.post('/auth/refresh', authController.refresh);
  app.post('/auth/logout', authController.logout);
  app.get('/families/<familyId>/messages', chatController.getMessages);
  app.post('/families/<familyId>/messages', chatController.postMessage);
  app.post('/tasks/<taskId>/events/updated', taskController.broadcastUpdate);

  // Thêm các routes cho các chức năng khác ở đây
  // ví dụ: final tasksController = TasksController(tasksRepository);
  // app.get('/tasks', tasksController.getTasks);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_jsonResponseMiddleware())
      .addHandler(app);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  socketService.attachToHttpServer(server);
  print('Server listening on port $port');
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
