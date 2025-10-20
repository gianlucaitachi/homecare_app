import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/auth_context.dart';
import '../repositories/message_repository.dart';
import '../services/socket_service.dart';
import '../utils/request_context.dart';

class ChatController {
  ChatController(this._messageRepository, this._socketService);

  final MessageRepository _messageRepository;
  final SocketService _socketService;

  Future<Response> getMessages(Request request, String familyId) async {
    final authContext = request.context['auth'] as AuthContext?;
    if (authContext == null) {
      return _unauthorizedResponse();
    }

    if (authContext.familyId != familyId) {
      return Response.forbidden(
        jsonEncode({'error': 'family_id_mismatch'}),
      );
    }

    final messages =
        await _messageRepository.getMessagesByFamily(authContext.familyId);
    final payload = messages.map((message) => message.toJson()).toList();
    return Response.ok(jsonEncode({'messages': payload}));
  }

  Future<Response> postMessage(Request request, String familyId) async {
    final authContext = request.context['auth'] as AuthContext?;
    if (authContext == null) {
      return _unauthorizedResponse();
    }

    if (authContext.familyId != familyId) {
      return Response.forbidden(
        jsonEncode({'error': 'family_id_mismatch'}),
      );
    }

    final senderId = authContext.userId;
    if (senderId.isEmpty) {
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
      familyId: authContext.familyId,
      senderId: senderId,
      content: content,
    );

    _socketService.broadcastChatMessage(message);

    return Response(201, body: jsonEncode({'message': message.toJson()}));
  }

  Future<Response> connectWebSocket(Request request, String familyId) async {
    final authContext = request.context['auth'] as AuthContext?;
    if (authContext == null) {
      return _unauthorizedResponse();
    }

    if (authContext.familyId != familyId) {
      return Response.forbidden(
        jsonEncode({'error': 'family_id_mismatch'}),
      );
    }

    final handler = webSocketHandler((WebSocketChannel channel) {
      _socketService.registerWebSocketClient(
        familyId: familyId,
        userId: authContext.userId,
        channel: channel,
      );
    });

    return handler(request);
  }

  Response _unauthorizedResponse() {
    return Response(401, body: jsonEncode({'error': 'unauthorized'}));
  }
}
