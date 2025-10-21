import 'package:homecare_app/features/members/domain/entities/member.dart';

abstract class MemberRepository {
  Future<List<Member>> fetchMembers(String familyId);
}
