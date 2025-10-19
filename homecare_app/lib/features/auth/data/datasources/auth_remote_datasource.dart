
import 'package:dio/dio.dart';

// Địa chỉ cơ sở của backend. 
// Khi chạy trên máy thật, bạn cần đổi 'localhost' thành địa chỉ IP của máy tính.
const String baseUrl = 'http://10.0.2.2:8080'; // 10.0.2.2 là localhost cho Android emulator

abstract class AuthRemoteDataSource {
  Future<Response> login({required String email, required String password});

  Future<Response> register({
    required String name,
    required String email,
    required String password,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio _dio;

  AuthRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  @override
  Future<Response> login({required String email, required String password}) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      return response;
    } on DioException {
      // Bắt lỗi từ Dio và ném ra để lớp Repository có thể xử lý
      rethrow;
    }
  }

  @override
  Future<Response> register(
      {required String name, required String email, required String password}) async {
    try {
      final response = await _dio.post(
        '$baseUrl/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
        },
      );
      return response;
    } on DioException {
      rethrow;
    }
  }
}
