import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homecare_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = _MockAuthRepository();
  });

  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'emits Authenticated when a valid session exists',
      setUp: () {
        when(() => mockAuthRepository.hasValidSession())
            .thenAnswer((_) async => true);
      },
      build: () => AuthBloc(authRepository: mockAuthRepository),
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => <AuthState>[Authenticated()],
      verify: (_) {
        verify(() => mockAuthRepository.hasValidSession()).called(1);
      },
    );
  });
}
