import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/storage_keys.dart';

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
    if (access != null) {
      await secureStorage.write(key: StorageKeys.accessToken, value: access);
    }
    if (refresh != null) {
      await secureStorage.write(key: StorageKeys.refreshToken, value: refresh);
    }
  }

  Future<void> logout() async {
    await apiClient.post('/auth/logout');
    await secureStorage.delete(key: StorageKeys.accessToken);
    await secureStorage.delete(key: StorageKeys.refreshToken);
  }
}
