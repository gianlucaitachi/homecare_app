import 'package:bloc_test/bloc_test.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class FakeAuthEvent extends Fake implements AuthEvent {}

class FakeAuthState extends Fake implements AuthState {}

void registerAuthFallbackValues() {
  registerFallbackValue(FakeAuthEvent());
  registerFallbackValue(FakeAuthState());
}
