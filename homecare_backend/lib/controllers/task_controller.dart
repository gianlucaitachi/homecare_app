import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../services/socket_service.dart';

class TaskController {
  TaskController(this._socketService);

  final SocketService _socketService;

  Future<Response> broadcastUpdate(Request request, String taskId) async {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>?;
    if (body == null) {
      return Response(400, body: jsonEncode({'error': 'invalid_body'}));
    }

    final familyId = body['familyId'] as String?;
    if (familyId == null || familyId.isEmpty) {
      return Response(400, body: jsonEncode({'error': 'familyId is required'}));
    }

    final payload = <String, dynamic>{
      'taskId': taskId,
      if (body['task'] != null) 'task': body['task'],
      if (body['changes'] != null) 'changes': body['changes'],
    };

    _socketService.broadcastTaskUpdated(familyId, payload);

    return Response.ok(jsonEncode({'status': 'broadcasted'}));
  }
}
