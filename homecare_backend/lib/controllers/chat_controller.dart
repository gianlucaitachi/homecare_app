import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../repositories/message_repository.dart';
import '../services/socket_service.dart';

class ChatController {
  ChatController(this._messageRepository, this._socketService);

  final MessageRepository _messageRepository;
  final SocketService _socketService;

  Future<Response> getMessages(Request request, String familyId) async {
    final messages = await _messageRepository.getMessagesByFamily(familyId);
    final payload = messages.map((message) => message.toJson()).toList();
    return Response.ok(jsonEncode({'messages': payload}));
  }

  Future<Response> postMessage(Request request, String familyId) async {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>?;
    if (body == null) {
      return Response(400, body: jsonEncode({'error': 'invalid_body'}));
    }

    final senderId = body['senderId'] as String?;
    final content = body['content'] as String?;

    if (senderId == null || content == null || content.trim().isEmpty) {
      return Response(400, body: jsonEncode({'error': 'senderId and content are required'}));
    }

    final message = await _messageRepository.createMessage(
      familyId: familyId,
      senderId: senderId,
      content: content,
    );

    _socketService.broadcastChatMessage(message);

    return Response(201, body: jsonEncode({'message': message.toJson()}));
  }
}
