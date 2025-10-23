import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homecare_app/features/auth/domain/entities/auth_session.dart';
import 'package:homecare_app/features/auth/domain/entities/user.dart';
import 'package:homecare_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = _MockAuthRepository();
  });

  group('AuthBloc', () {
    const user = User(
      id: 'user-1',
      name: 'Test User',
      email: 'test@example.com',
      familyId: 'family-1',
    );
    const session = AuthSession(
      user: user,
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );

    blocTest<AuthBloc, AuthState>(
      'emits Authenticated when a valid session exists',
      setUp: () {
        when(() => mockAuthRepository.restoreSession())
            .thenAnswer((_) async => session);
      },
      build: () => AuthBloc(authRepository: mockAuthRepository),
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => const <AuthState>[Authenticated(session)],
      verify: (_) {
        verify(() => mockAuthRepository.restoreSession()).called(1);
      },
    );
  });
}
