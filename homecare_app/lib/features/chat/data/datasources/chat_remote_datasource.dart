import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../models/chat_message.dart';

class ChatRemoteDataSource {
  ChatRemoteDataSource({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<ChatMessage>> fetchMessages(String familyId) async {
    final response = await _dio.get(
      '${AppConstants.apiBaseUrl}/families/$familyId/messages',
    );
    final data = response.data as Map<String, dynamic>;
    final messages = data['messages'] as List<dynamic>? ?? [];
    return messages
        .map((json) => ChatMessage.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<ChatMessage> createMessage({
    required String familyId,
    required String senderId,
    required String content,
  }) async {
    final response = await _dio.post(
      '${AppConstants.apiBaseUrl}/families/$familyId/messages',
      data: {
        'senderId': senderId,
        'content': content,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return ChatMessage.fromJson(Map<String, dynamic>.from(data['message'] as Map));
  }
}
