import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRemoteDataSource {
  final ApiClient apiClient;
  final FlutterSecureStorage secureStorage;

  AuthRemoteDataSource(this.apiClient, this.secureStorage);

  Future<void> login(String email, String password) async {
    final resp = await apiClient.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final access = resp.data['accessToken'] as String?;
    final refresh = resp.data['refreshToken'] as String?;
    if (access != null) await secureStorage.write(key: 'access_token', value: access);
    if (refresh != null) await secureStorage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> logout() async {
    await apiClient.post('/auth/logout');
    await secureStorage.delete(key: 'access_token');
    await secureStorage.delete(key: 'refresh_token');
  }
}
