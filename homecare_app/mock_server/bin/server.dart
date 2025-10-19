
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';
import 'package:dargon2_flutter/dargon2_flutter.dart';
import 'package:dargon2_flutter/dargon2_interface.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

// Biến toàn cục để giữ kết nối database, sẽ được khởi tạo trong main()
late PostgreSQLConnection dbConnection;

// Khóa bí mật để ký JWT. Trong ứng dụng thật, hãy lưu nó an toàn hơn!
const jwtSecret = 'your-super-secret-and-long-key-that-is-at-least-32-chars';

// Hàm trợ giúp để tạo response JSON chuẩn
Response jsonResponse(int statusCode, Map<String, dynamic> body) => Response(
      statusCode,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json'},
    );

// Middleware để xác thực JWT
Middleware checkJwtMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      // Bỏ qua xác thực cho các route đăng ký và đăng nhập
      if (request.url.path.startsWith('auth/register') ||
          request.url.path.startsWith('auth/login')) {
        return innerHandler(request);
      }

      final authHeader = request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return jsonResponse(401, {'error': 'Missing or invalid token'});
      }

      final token = authHeader.substring(7); // Bỏ "Bearer "
      try {
        final jwt = JWT.verify(token, SecretKey(jwtSecret));
        // Gắn thông tin user vào request để các handler sau có thể sử dụng
        final updatedRequest = request.change(context: {'jwt': jwt.payload});
        return innerHandler(updatedRequest);
      } on JWTExpiredException {
        return jsonResponse(401, {'error': 'Token has expired'});
      } on JWTException catch (e) {
        return jsonResponse(401, {'error': 'Invalid token: ${e.message}'});
      }
    };
  };
}


void main() async {
  // === KẾT NỐI DATABASE ===
  // Thay đổi các thông tin này cho phù hợp với cấu hình PostgreSQL của bạn
  dbConnection = PostgreSQLConnection(
    'localhost', // Host
    5432, // Port
    'homecare_db', // Tên database
    username: 'postgres', // Username
    password: 'your_password', // Mật khẩu của bạn
  );
  await dbConnection.open();
  print('✅ Connected to PostgreSQL database');

  final app = Router();

  // === CÁC AUTH ENDPOINT VỚI DATABASE ===

  // [POST] /auth/register - Đăng ký với mật khẩu được mã hóa
  app.post('/auth/register', (Request req) async {
    final payload = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final email = payload['email'] as String?;
    final password = payload['password'] as String?;
    final name = payload['name'] as String?;

    if (email == null || password == null || name == null) {
      return jsonResponse(400, {'error': 'name, email, and password are required'});
    }

    // 1. Kiểm tra email đã tồn tại chưa
    final results = await dbConnection.query(
      'SELECT id FROM users WHERE email = @email LIMIT 1',
      substitutionValues: {'email': email},
    );

    if (results.isNotEmpty) {
      return jsonResponse(409, {'error': 'User with this email already exists'});
    }

    // 2. Mã hóa mật khẩu
    DArgon2Flutter.init();
    final s = Salt.newSalt();
    final result = await dArgon2.hashPasswordString(password, salt: s);
    final passwordHash = result.encodedString;

    // 3. Lưu người dùng mới vào database
    final insertResult = await dbConnection.query(
      'INSERT INTO users (name, email, password_hash) VALUES (@name, @email, @hash) RETURNING id, name, email',
      substitutionValues: {
        'name': name,
        'email': email,
        'hash': passwordHash,
      },
    );
    
    final newUser = insertResult.first.toColumnMap();
    print('✅ New user registered: $newUser');

    return jsonResponse(201, {'user': newUser});
  });

  // [POST] /auth/login - Đăng nhập và tạo JWT
  app.post('/auth/login', (Request req) async {
    final payload = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final email = payload['email'] as String?;
    final password = payload['password'] as String?;

    if (email == null || password == null) {
      return jsonResponse(400, {'error': 'Email and password are required'});
    }
    
    // 1. Tìm người dùng
    final results = await dbConnection.query(
        'SELECT id, name, email, password_hash FROM users WHERE email = @email LIMIT 1',
        substitutionValues: {'email': email});

    if (results.isEmpty) {
        return jsonResponse(401, {'error': 'invalid_credentials'});
    }

    final userRow = results.first;
    final user = userRow.toColumnMap();
    final passwordHash = user['password_hash'] as String;

    // 2. Xác thực mật khẩu
    DArgon2Flutter.init();
    final isPasswordValid = await dArgon2.verifyHashString(password, passwordHash);

    if (!isPasswordValid) {
        return jsonResponse(401, {'error': 'invalid_credentials'});
    }

    // 3. Tạo Access Token và Refresh Token
    final accessToken = JWT(
      {'userId': user['id'], 'name': user['name']},
      issuer: 'homecare_app',
      jwtId: 'access_${DateTime.now().millisecondsSinceEpoch}',
    ).sign(SecretKey(jwtSecret), expiresIn: Duration(minutes: 15));
    
    final refreshToken = JWT(
      {'userId': user['id']},
      issuer: 'homecare_app',
       jwtId: 'refresh_${DateTime.now().millisecondsSinceEpoch}',
    ).sign(SecretKey(jwtSecret), expiresIn: Duration(days: 7));


    print('✅ User logged in: ${user['email']}');

    return jsonResponse(200, {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': {'id': user['id'], 'name': user['name'], 'email': user['email']}
    });
  });

  // [GET] /auth/me - Lấy thông tin user từ JWT
  app.get('/auth/me', (Request req) {
    // Middleware đã xử lý việc xác thực token
    // Chúng ta chỉ cần lấy thông tin từ context
    final jwtPayload = req.context['jwt'] as Map<String, dynamic>;
    final userId = jwtPayload['userId'];
    final name = jwtPayload['name'];

    print('✅ Checked auth status for user id: $userId');

    // Trong thực tế, bạn có thể muốn truy vấn lại DB để lấy thông tin user mới nhất
    return jsonResponse(200, {
        'user': {'id': userId, 'name': name}
    });
  });


  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(checkJwtMiddleware()) // Thêm middleware JWT
      .addHandler(app);

  final server = await io.serve(handler, 'localhost', 8080);
  print('🚀 Server running at http://${server.address.host}:${server.port}');
}
