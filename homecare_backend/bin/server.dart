import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

// Import các thành phần theo đúng kiến trúc
import 'package:homecare_backend/db/postgres_client.dart';
import 'package:homecare_backend/repositories/user_repository.dart';
import 'package:homecare_backend/controllers/auth_controller.dart';

Future<void> main(List<String> args) async {
  // 1. Khởi tạo kết nối CSDL
  final dbClient = PostgresClient.fromEnv();
  await dbClient.connect();

  // 2. Khởi tạo các Repository
  final userRepository = UserRepository(dbClient);

  // 3. Khởi tạo các Controller với Repository tương ứng
  final authController = AuthController(userRepository);

  // 4. Thiết lập các routes
  final app = Router();
  app.post('/auth/register', authController.register);
  app.post('/auth/login', authController.login);
  app.post('/auth/refresh', authController.refresh);
  app.post('/auth/logout', authController.logout);

  // Thêm các routes cho các chức năng khác ở đây
  // ví dụ: final tasksController = TasksController(tasksRepository);
  // app.get('/tasks', tasksController.getTasks);

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_jsonResponseMiddleware())
      .addHandler(app);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
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
