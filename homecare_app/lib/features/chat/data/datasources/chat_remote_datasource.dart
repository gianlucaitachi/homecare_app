import '../../../../core/api/api_client.dart';
import '../models/chat_message.dart';

class ChatRemoteDataSource {
  ChatRemoteDataSource({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<ChatMessage>> fetchMessages(String familyId) async {
    final response = await _apiClient.get('api/families/$familyId/messages');
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
    final response = await _apiClient.post(
      'api/families/$familyId/messages',
      data: {'senderId': senderId, 'content': content},
    );
    final data = response.data as Map<String, dynamic>;
    return ChatMessage.fromJson(Map<String, dynamic>.from(data['message'] as Map));
  }
}
