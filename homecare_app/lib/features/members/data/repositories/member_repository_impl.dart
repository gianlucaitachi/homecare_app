import 'package:homecare_app/features/members/data/datasources/member_remote_data_source.dart';
import 'package:homecare_app/features/members/domain/entities/member.dart';
import 'package:homecare_app/features/members/domain/repositories/member_repository.dart';

class MemberRepositoryImpl implements MemberRepository {
  MemberRepositoryImpl({required MemberRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final MemberRemoteDataSource _remoteDataSource;

  @override
  Future<List<Member>> fetchMembers(String familyId) {
    return _remoteDataSource.fetchMembers(familyId);
  }
}
