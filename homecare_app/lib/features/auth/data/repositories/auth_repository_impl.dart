
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:homecare_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:homecare_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final FlutterSecureStorage _secureStorage;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required FlutterSecureStorage secureStorage,
  })  : _remoteDataSource = remoteDataSource,
        _secureStorage = secureStorage;

  @override
  Future<void> login({required String email, required String password}) async {
    try {
      final response = await _remoteDataSource.login(email: email, password: password);
      
      // Lấy token từ response
      final accessToken = response.data['accessToken'];
      final refreshToken = response.data['refreshToken'];

      if (accessToken == null || refreshToken == null) {
        throw 'Server response is missing tokens';
      }

      // Lưu token vào secure storage
      await _secureStorage.write(key: 'access_token', value: accessToken);
      await _secureStorage.write(key: 'refresh_token', value: refreshToken);

    } on DioException catch (e) {
      // Xử lý lỗi từ Dio
      if (e.response?.statusCode == 401) {
        throw 'Invalid credentials. Please try again.';
      } else {
        throw 'A network error occurred. Please check your connection.';
      }
    } catch (e) {
      // Bắt các lỗi khác
      rethrow;
    }
  }

  @override
  Future<void> register(
      {required String name, required String email, required String password}) async {
    try {
      final response = await _remoteDataSource.register(
        name: name,
        email: email,
        password: password,
      );

      final accessToken = response.data['accessToken'];
      final refreshToken = response.data['refreshToken'];

      if (accessToken == null || refreshToken == null) {
        throw 'Server response is missing tokens';
      }

      await _secureStorage.write(key: 'access_token', value: accessToken);
      await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw 'A user with this email already exists.';
      } else {
        throw 'An error occurred during registration. Please try again.';
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    // Xóa tất cả token khi đăng xuất
    await _secureStorage.deleteAll();
  }

  @override
  Future<bool> hasValidSession() async {
    final accessToken = await _secureStorage.read(key: 'access_token');
    final refreshToken = await _secureStorage.read(key: 'refresh_token');

    final hasAccessToken = accessToken != null && accessToken.isNotEmpty;
    final hasRefreshToken = refreshToken != null && refreshToken.isNotEmpty;

    return hasAccessToken && hasRefreshToken;
  }
}
