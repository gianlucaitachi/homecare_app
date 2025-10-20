import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:homecare_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:homecare_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockAuthRemoteDataSource remoteDataSource;
  late MockFlutterSecureStorage secureStorage;
  late AuthRepositoryImpl repository;

  setUp(() {
    remoteDataSource = MockAuthRemoteDataSource();
    secureStorage = MockFlutterSecureStorage();
    repository = AuthRepositoryImpl(
      remoteDataSource: remoteDataSource,
      secureStorage: secureStorage,
    );
  });

  group('login', () {
    test('throws Invalid credentials error when backend responds with 401', () async {
      when(
        () => remoteDataSource.login(
          email: any<String>(named: 'email'),
          password: any<String>(named: 'password'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/login'),
            statusCode: 401,
            statusMessage: 'Unauthorized',
            data: {'error': 'invalid_credentials'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      await expectLater(
        repository.login(email: 'foo@bar.com', password: 'wrong'),
        throwsA(equals('Invalid credentials. Please try again.')),
      );

      verify(
        () => remoteDataSource.login(
          email: 'foo@bar.com',
          password: 'wrong',
        ),
      ).called(1);
      verifyNever(
        () => secureStorage.write(
          key: any<String>(named: 'key'),
          value: any<String?>(named: 'value'),
        ),
      );
    });
  });
}
