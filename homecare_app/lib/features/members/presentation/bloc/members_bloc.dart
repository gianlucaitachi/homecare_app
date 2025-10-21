import 'package:bloc/bloc.dart';
import 'package:homecare_app/features/members/domain/entities/member.dart';
import 'package:homecare_app/features/members/domain/repositories/member_repository.dart';

import 'members_event.dart';
import 'members_state.dart';

class MembersBloc extends Bloc<MembersEvent, MembersState> {
  MembersBloc({
    required MemberRepository repository,
    String? familyId,
  })  : _repository = repository,
        _familyId = familyId,
        super(MembersState(familyId: familyId)) {
    on<MembersRequested>(_onMembersRequested);
    on<MembersRefreshed>(_onMembersRefreshed);
  }

  final MemberRepository _repository;
  String? _familyId;

  String? get familyId => _familyId;

  Future<void> _onMembersRequested(
    MembersRequested event,
    Emitter<MembersState> emit,
  ) async {
    final targetFamilyId = event.familyId ?? _familyId ?? state.familyId;
    if (targetFamilyId == null || targetFamilyId.isEmpty) {
      emit(
        state.copyWith(
          status: MembersStatus.failure,
          errorMessage: 'Missing family ID',
        ),
      );
      return;
    }

    if (!event.silent) {
      emit(
        state.copyWith(
          status: MembersStatus.loading,
          errorMessage: null,
          familyId: targetFamilyId,
        ),
      );
    } else {
      emit(state.copyWith(familyId: targetFamilyId));
    }

    _familyId = targetFamilyId;
    try {
      final members = await _repository.fetchMembers(targetFamilyId);
      emit(
        state.copyWith(
          status: MembersStatus.success,
          members: members,
          errorMessage: null,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: MembersStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onMembersRefreshed(
    MembersRefreshed event,
    Emitter<MembersState> emit,
  ) async {
    final targetFamilyId = _familyId ?? state.familyId;
    if (targetFamilyId == null || targetFamilyId.isEmpty) {
      return;
    }

    try {
      emit(state.copyWith(errorMessage: null));
      final members = await _repository.fetchMembers(targetFamilyId);
      emit(
        state.copyWith(
          status: MembersStatus.success,
          members: members,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: MembersStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Member? findMember(String? memberId) => state.memberById(memberId);
}
