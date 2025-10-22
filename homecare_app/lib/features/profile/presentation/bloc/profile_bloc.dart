import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:homecare_app/features/auth/domain/entities/user.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:homecare_app/features/profile/domain/repositories/profile_repository.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc({required ProfileRepository profileRepository, required AuthBloc authBloc})
      : _profileRepository = profileRepository,
        _authBloc = authBloc,
        super(const ProfileState()) {
    on<ProfileSubmitted>(_onProfileSubmitted);
  }

  final ProfileRepository _profileRepository;
  final AuthBloc _authBloc;

  Future<void> _onProfileSubmitted(
    ProfileSubmitted event,
    Emitter<ProfileState> emit,
  ) async {
    emit(state.copyWith(status: ProfileStatus.loading, clearError: true));
    try {
      final user = await _profileRepository.updateCurrentUser(
        name: event.name,
        email: event.email,
      );
      _authBloc.add(AuthUserUpdated(user));
      emit(state.copyWith(status: ProfileStatus.success, user: user, clearError: true));
    } catch (error) {
      emit(
        state.copyWith(
          status: ProfileStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
