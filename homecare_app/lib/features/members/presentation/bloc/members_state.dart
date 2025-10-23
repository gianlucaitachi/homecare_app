import 'package:equatable/equatable.dart';
import 'package:homecare_app/features/members/domain/entities/member.dart';

enum MembersStatus { initial, loading, success, failure }

class MembersState extends Equatable {
  const MembersState({
    this.status = MembersStatus.initial,
    this.members = const <Member>[],
    this.errorMessage,
    this.familyId,
  });

  final MembersStatus status;
  final List<Member> members;
  final String? errorMessage;
  final String? familyId;

  bool get isLoading => status == MembersStatus.loading;

  MembersState copyWith({
    MembersStatus? status,
    List<Member>? members,
    String? errorMessage,
    String? familyId,
  }) {
    return MembersState(
      status: status ?? this.status,
      members: members ?? this.members,
      errorMessage: errorMessage,
      familyId: familyId ?? this.familyId,
    );
  }

  Member? memberById(String? id) {
    if (id == null) return null;
    for (final member in members) {
      if (member.id == id) {
        return member;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [status, members, errorMessage, familyId];
}
