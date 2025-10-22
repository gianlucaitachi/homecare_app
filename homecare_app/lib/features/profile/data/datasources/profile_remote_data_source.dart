import 'package:homecare_app/core/api/api_client.dart';
import 'package:homecare_app/features/auth/data/models/user_model.dart';

abstract class ProfileRemoteDataSource {
  Future<UserModel> updateCurrentUser({required String name, required String email});
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<UserModel> updateCurrentUser({
    required String name,
    required String email,
  }) async {
    final response = await _apiClient.put(
      'api/users/me',
      data: {
        'name': name,
        'email': email,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final userJson = data['user'];
      if (userJson is Map<String, dynamic>) {
        return UserModel.fromJson(userJson);
      }

      return UserModel.fromJson(data);
    }

    throw 'Unexpected server response when updating profile';
  }
}
