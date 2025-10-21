import '../../../../core/api/api_client.dart';
import '../models/member_model.dart';

abstract class MemberRemoteDataSource {
  Future<List<MemberModel>> fetchMembers(String familyId);
}

class MemberRemoteDataSourceImpl implements MemberRemoteDataSource {
  MemberRemoteDataSourceImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<MemberModel>> fetchMembers(String familyId) async {
    final response = await _apiClient.get('api/families/$familyId/members');
    final data = response.data['members'];
    if (data is List<dynamic>) {
      return MemberModel.fromJsonList(data);
    }
    return const <MemberModel>[];
  }
}
