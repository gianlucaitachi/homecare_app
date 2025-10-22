import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:homecare_app/core/constants/storage_keys.dart';
import 'package:homecare_app/features/auth/data/models/user_model.dart';
import 'package:homecare_app/features/auth/domain/entities/user.dart';
import 'package:homecare_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:homecare_app/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required ProfileRemoteDataSource remoteDataSource,
    required FlutterSecureStorage secureStorage,
  })  : _remoteDataSource = remoteDataSource,
        _secureStorage = secureStorage;

  final ProfileRemoteDataSource _remoteDataSource;
  final FlutterSecureStorage _secureStorage;

  @override
  Future<User> updateCurrentUser({
    required String name,
    required String email,
  }) async {
    try {
      final user = await _remoteDataSource.updateCurrentUser(
        name: name,
        email: email,
      );

      await _secureStorage.write(
        key: StorageKeys.currentUser,
        value: jsonEncode(user.toJson()),
      );

      return user;
    } on DioException catch (error) {
      final message = error.response?.data is Map<String, dynamic>
          ? (error.response?.data['message'] as String? ?? 'Failed to update profile.')
          : 'Failed to update profile. Please try again later.';
      throw message;
    } catch (error) {
      throw error.toString();
    }
  }
}
