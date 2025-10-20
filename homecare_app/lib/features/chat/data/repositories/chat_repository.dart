import '../datasources/chat_remote_datasource.dart';
import '../models/chat_message.dart';

class ChatRepository {
  ChatRepository({required ChatRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  final ChatRemoteDataSource _remoteDataSource;

  Future<List<ChatMessage>> fetchMessages(String familyId) {
    return _remoteDataSource.fetchMessages(familyId);
  }

  Future<ChatMessage> createMessage({
    required String familyId,
    required String senderId,
    required String content,
  }) {
    return _remoteDataSource.createMessage(
      familyId: familyId,
      senderId: senderId,
      content: content,
    );
  }
}
