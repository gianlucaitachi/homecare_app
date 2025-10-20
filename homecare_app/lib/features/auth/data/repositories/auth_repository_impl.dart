
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final FlutterSecureStorage _secureStorage;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required FlutterSecureStorage secureStorage,
  })  : _remoteDataSource = remoteDataSource,
        _secureStorage = secureStorage;

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    try {
      final response = await _remoteDataSource.login(email: email, password: password);

      final accessToken = response.data['accessToken'] as String?;
      final refreshToken = response.data['refreshToken'] as String?;
      final userJson = response.data['user'] as Map<String, dynamic>?;

      if (accessToken == null || refreshToken == null || userJson == null) {
        throw 'Server response is missing credentials';
      }

      final user = UserModel.fromJson(userJson);

      await _secureStorage.write(key: StorageKeys.accessToken, value: accessToken);
      await _secureStorage.write(key: StorageKeys.refreshToken, value: refreshToken);
      await _secureStorage.write(
        key: StorageKeys.currentUser,
        value: jsonEncode(user.toJson()),
      );

      return AuthSession(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Invalid credentials. Please try again.';
      } else {
        throw 'A network error occurred. Please check your connection.';
      }
    }
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _remoteDataSource.register(
        name: name,
        email: email,
        password: password,
      );

      final accessToken = response.data['accessToken'] as String?;
      final refreshToken = response.data['refreshToken'] as String?;
      final userJson = response.data['user'] as Map<String, dynamic>?;

      if (accessToken == null || refreshToken == null || userJson == null) {
        throw 'Server response is missing credentials';
      }

      final user = UserModel.fromJson(userJson);

      await _secureStorage.write(key: StorageKeys.accessToken, value: accessToken);
      await _secureStorage.write(key: StorageKeys.refreshToken, value: refreshToken);
      await _secureStorage.write(
        key: StorageKeys.currentUser,
        value: jsonEncode(user.toJson()),
      );

      return AuthSession(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw 'A user with this email already exists.';
      } else {
        throw 'An error occurred during registration. Please try again.';
      }
    }
  }

  @override
  Future<void> logout() async {
    await Future.wait([
      _secureStorage.delete(key: StorageKeys.accessToken),
      _secureStorage.delete(key: StorageKeys.refreshToken),
      _secureStorage.delete(key: StorageKeys.currentUser),
    ]);
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final accessTokenFuture = _secureStorage.read(key: StorageKeys.accessToken);
    final refreshTokenFuture = _secureStorage.read(key: StorageKeys.refreshToken);
    final userFuture = _secureStorage.read(key: StorageKeys.currentUser);

    final accessToken = await accessTokenFuture;
    final refreshToken = await refreshTokenFuture;
    final userRaw = await userFuture;

    if (accessToken == null || refreshToken == null || userRaw == null) {
      return null;
    }

    try {
      final json = jsonDecode(userRaw) as Map<String, dynamic>;
      final user = UserModel.fromJson(json);
      return AuthSession(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } catch (_) {
      await logout();
      return null;
    }
  }
}
