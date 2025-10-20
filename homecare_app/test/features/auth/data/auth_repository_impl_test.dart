import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homecare_app/core/constants/storage_keys.dart';
import 'package:homecare_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:homecare_app/features/auth/data/repositories/auth_repository_impl.dart';

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

  test('hasValidSession returns true when access and refresh tokens are saved', () async {
    when(() => secureStorage.read(key: StorageKeys.accessToken)).thenAnswer((_) async => 'access');
    when(() => secureStorage.read(key: StorageKeys.refreshToken)).thenAnswer((_) async => 'refresh');

    final result = await repository.hasValidSession();

    expect(result, isTrue);
    verify(() => secureStorage.read(key: StorageKeys.accessToken)).called(1);
    verify(() => secureStorage.read(key: StorageKeys.refreshToken)).called(1);
  });
}
