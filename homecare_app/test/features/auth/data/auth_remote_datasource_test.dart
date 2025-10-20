import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homecare_app/core/api/api_client.dart';
import 'package:homecare_app/features/auth/data/datasources/auth_remote_datasource.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient apiClient;
  late AuthRemoteDataSourceImpl dataSource;

  setUp(() {
    apiClient = _MockApiClient();
    dataSource = AuthRemoteDataSourceImpl(apiClient: apiClient);
  });

  test('login posts to /auth/login', () async {
    final response = Response(
      data: {
        'accessToken': 'access',
        'refreshToken': 'refresh',
        'user': {'id': '1'},
      },
      statusCode: 200,
      requestOptions: RequestOptions(path: '/auth/login'),
    );

    when(() => apiClient.post(
          '/auth/login',
          data: any(named: 'data'),
        )).thenAnswer((_) async => response);

    final result = await dataSource.login(
      email: 'alice@example.com',
      password: 'secret',
    );

    expect(result, same(response));

    final verification = verify(() => apiClient.post(
          '/auth/login',
          data: captureAny(named: 'data'),
        ));
    verification.called(1);
    final captured = verification.captured.single as Map<String, dynamic>;
    expect(captured, equals({'email': 'alice@example.com', 'password': 'secret'}));
  });

  test('register posts to /auth/register', () async {
    final response = Response(
      data: {
        'user': {'id': '1'},
      },
      statusCode: 200,
      requestOptions: RequestOptions(path: '/auth/register'),
    );

    when(() => apiClient.post(
          '/auth/register',
          data: any(named: 'data'),
        )).thenAnswer((_) async => response);

    final result = await dataSource.register(
      name: 'Alice',
      email: 'alice@example.com',
      password: 'secret',
    );

    expect(result, same(response));

    final verification = verify(() => apiClient.post(
          '/auth/register',
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
