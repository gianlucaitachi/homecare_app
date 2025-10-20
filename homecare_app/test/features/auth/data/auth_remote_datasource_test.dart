import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homecare_app/core/constants/app_constants.dart';
import 'package:homecare_app/features/auth/data/datasources/auth_remote_datasource.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late AuthRemoteDataSourceImpl dataSource;

  setUp(() {
    dio = _MockDio();
    dataSource = AuthRemoteDataSourceImpl(dio: dio);
  });

  test('login posts to /api/auth/login', () async {
    final response = Response(
      data: {
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'user': {'id': '1'},
      },
      statusCode: 200,
      requestOptions:
          RequestOptions(path: '${AppConstants.apiBaseUrl}/auth/login'),
    );

    when(() => dio.post(
          '${AppConstants.apiBaseUrl}/auth/login',
          data: any(named: 'data'),
        )).thenAnswer((_) async => response);

    final result = await dataSource.login(
      email: 'alice@example.com',
      password: 'secret',
    );

    expect(result, same(response));

    final verification = verify(() => dio.post(
          '${AppConstants.apiBaseUrl}/auth/login',
          data: captureAny(named: 'data'),
        ));
    verification.called(1);
    final captured = verification.captured.single as Map<String, dynamic>;
    expect(captured, equals({'email': 'alice@example.com', 'password': 'secret'}));
  });

  test('register posts to /api/auth/register', () async {
    final response = Response(
      data: {
        'user': {'id': '1'},
      },
      statusCode: 200,
      requestOptions:
          RequestOptions(path: '${AppConstants.apiBaseUrl}/auth/register'),
    );

    when(() => dio.post(
          '${AppConstants.apiBaseUrl}/auth/register',
          data: any(named: 'data'),
        )).thenAnswer((_) async => response);

    final result = await dataSource.register(
      name: 'Alice',
      email: 'alice@example.com',
      password: 'secret',
    );

    expect(result, same(response));

    final verification = verify(() => dio.post(
          '${AppConstants.apiBaseUrl}/auth/register',
          data: captureAny(named: 'data'),
        ));
    verification.called(1);
    final captured = verification.captured.single as Map<String, dynamic>;
    expect(
      captured,
      equals({
        'name': 'Alice',
        'email': 'alice@example.com',
        'password': 'secret',
      }),
    );
  });
}
