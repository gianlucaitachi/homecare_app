import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:homecare_app/core/api/api_client.dart';
import 'package:homecare_app/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:homecare_app/features/chat/data/models/chat_message.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient apiClient;
  late ChatRemoteDataSource dataSource;

  setUp(() {
    apiClient = _MockApiClient();
    dataSource = ChatRemoteDataSource(apiClient: apiClient);
  });

  test('fetchMessages requests /families/<id>/messages and parses data', () async {
    final response = Response(
      data: {
        'messages': [
          {
            'id': '1',
            'familyId': 'family-1',
            'senderId': 'user-1',
            'content': 'Hello',
            'createdAt': '2024-01-01T12:00:00.000Z',
          }
        ],
      },
      statusCode: 200,
      requestOptions: RequestOptions(path: '/families/family-1/messages'),
    );

    when(() => apiClient.get(
          '/families/family-1/messages',
        )).thenAnswer((_) async => response);

    final messages = await dataSource.fetchMessages('family-1');

    expect(messages, hasLength(1));
    expect(messages.first, isA<ChatMessage>());
    expect(messages.first.content, equals('Hello'));

    verify(() => apiClient.get('/families/family-1/messages'))
        .called(1);
  });

  test('createMessage posts to /families/<id>/messages and returns created message', () async {
    final response = Response(
      data: {
        'message': {
          'id': '2',
          'familyId': 'family-1',
          'senderId': 'user-2',
          'content': 'Hi there',
          'createdAt': '2024-01-02T08:00:00.000Z',
        }
      },
      statusCode: 201,
      requestOptions: RequestOptions(path: '/families/family-1/messages'),
    );

    when(() => apiClient.post(
          '/families/family-1/messages',
          data: any(named: 'data'),
        )).thenAnswer((_) async => response);

    final message = await dataSource.createMessage(
      familyId: 'family-1',
      senderId: 'user-2',
      content: 'Hi there',
    );

    expect(message.id, equals('2'));
    expect(message.content, equals('Hi there'));

    final verification = verify(() => apiClient.post(
          '/families/family-1/messages',
          data: captureAny(named: 'data'),
        ));
    verification.called(1);
    final captured = verification.captured.single as Map<String, dynamic>;
    expect(
      captured,
      equals({'senderId': 'user-2', 'content': 'Hi there'}),
    );
  });
}
