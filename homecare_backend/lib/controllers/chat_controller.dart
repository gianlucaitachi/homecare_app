import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../repositories/message_repository.dart';
import '../services/socket_service.dart';
import '../utils/request_context.dart';

class ChatController {
  ChatController(this._messageRepository, this._socketService);

  final MessageRepository _messageRepository;
  final SocketService _socketService;

  Future<Response> getMessages(Request request, String familyId) async {
    if (request.authenticatedUserId == null) {
      return _unauthorizedResponse();
    }

    final messages = await _messageRepository.getMessagesByFamily(familyId);
    final payload = messages.map((message) => message.toJson()).toList();
    return Response.ok(jsonEncode({'messages': payload}));
  }

  Future<Response> postMessage(Request request, String familyId) async {
    final senderId = request.authenticatedUserId;
    if (senderId == null) {
      return _unauthorizedResponse();
    }

    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>?;
    if (body == null) {
      return Response(400, body: jsonEncode({'error': 'invalid_body'}));
    }

    final content = body['content'] as String?;

    if (content == null || content.trim().isEmpty) {
      return Response(400, body: jsonEncode({'error': 'content is required'}));
    }

    final message = await _messageRepository.createMessage(
      familyId: familyId,
      senderId: senderId,
      content: content,
    );

    _socketService.broadcastChatMessage(message);

    return Response(201, body: jsonEncode({'message': message.toJson()}));
  }

  Response _unauthorizedResponse() {
    return Response(401, body: jsonEncode({'error': 'unauthorized'}));
  }
}
