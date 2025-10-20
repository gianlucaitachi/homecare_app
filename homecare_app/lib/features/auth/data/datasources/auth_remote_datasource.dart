
import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';

abstract class AuthRemoteDataSource {
  Future<Response> login({required String email, required String password});

  Future<Response> register({
    required String name,
    required String email,
    required String password,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<Response> login({required String email, required String password}) async {
    try {
      final response = await _apiClient.post(
        'api/auth/login',
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
      final response = await _apiClient.post(
        'api/auth/register',
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
