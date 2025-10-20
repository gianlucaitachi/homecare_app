import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import '../models/auth_context.dart';
import '../models/task_model.dart';
import '../repositories/task_repository.dart';
import '../services/task_event_hub.dart';

class TaskController {
  TaskController(this._repository, this._eventHub);

  final TaskRepository _repository;
  final TaskEventHub _eventHub;

  Router get router {
    final router = Router();
    router.get('/', listTasks);
    router.post('/', createTask);
    router.post('/complete-qr', completeByQrPayload);
    router.get('/<id>', getTaskById);
    router.put('/<id>', updateTask);
    router.delete('/<id>', deleteTask);
    router.post('/<id>/assign', assignTask);
    router.post('/<id>/events/updated', broadcastUpdate);
    return router;
  }

  Handler get socketHandler => (Request request) {
        final familyId = request.url.queryParameters['familyId'];
        final handler = webSocketHandler((socket) {
          _eventHub.addClient(socket, familyId: familyId);
        });
        return handler(request);
      };

  Future<Response> listTasks(Request request) async {
    final auth = request.context['auth'] as AuthContext?;
    if (auth == null) {
      return Response(
        400,
        body: jsonEncode({'error': 'missing_authentication_context'}),
      );
    }

    final overrideFamilyId = request.url.queryParameters['familyId'];
    if (overrideFamilyId != null) {
      if (overrideFamilyId != auth.familyId) {
        return Response.forbidden(
          jsonEncode({'error': 'family_id_mismatch'}),
        );
      }

      return Response(
        400,
        body: jsonEncode({'error': 'family_id_query_not_allowed'}),
      );
    }

    final tasks = await _repository.listTasks(familyId: auth.familyId);
    return Response.ok(jsonEncode({
      'tasks': tasks.map((t) => t.toJson()).toList(),
    }));
  }

  Future<Response> createTask(Request request) async {
    final payload = await _decodeJsonBody(request);
    final familyId = payload['familyId'] as String?;
    final title = payload['title'] as String?;

    if (familyId == null || title == null) {
      return Response(400,
          body: jsonEncode({'error': 'familyId and title are required'}));
    }

    final description = payload['description'] as String?;
    final assignedUserId = payload['assignedUserId'] as String?;
    final dueDateStr = payload['dueDate'] as String?;
    final dueDate = _parseDateTime(dueDateStr);

    final task = await _repository.createTask(
      familyId: familyId,
      title: title,
      description: description,
      dueDate: dueDate,
      assignedUserId: assignedUserId,
    );

    _eventHub.broadcast({
      'type': 'task.created',
      'task': task.toJson(),
      'familyId': task.familyId,
    });

    return Response(201, body: jsonEncode({'task': task.toJson()}));
  }

  Future<Response> getTaskById(Request request, String id) async {
    final task = await _repository.getTask(id);
    if (task == null) {
      return Response.notFound(jsonEncode({'error': 'task_not_found'}));
    }
    return Response.ok(jsonEncode({'task': task.toJson()}));
  }

  Future<Response> updateTask(Request request, String id) async {
    final existing = await _repository.getTask(id);
    if (existing == null) {
      return Response.notFound(jsonEncode({'error': 'task_not_found'}));
    }

    final payload = await _decodeJsonBody(request);
    final fields = <String, dynamic>{};

    if (payload.containsKey('title')) {
      final title = payload['title'];
      if (title is String && title.isNotEmpty) {
        fields['title'] = title;
      }
    }

    if (payload.containsKey('description')) {
      fields['description'] = payload['description'];
    }

    if (payload.containsKey('dueDate')) {
      fields['due_date'] = _parseDateTime(payload['dueDate'] as String?);
    }

    if (payload.containsKey('assignedUserId')) {
      fields['assigned_user_id'] = payload['assignedUserId'];
    }

    if (payload.containsKey('status')) {
      final status = payload['status'] as String?;
      if (status != null &&
          ['pending', 'in_progress', 'completed'].contains(status)) {
        fields['status'] = status;
        if (status == TaskStatus.completed.value) {
          fields['completed_at'] = DateTime.now();
        } else {
          fields['completed_at'] = null;
        }
      }
    }

    final updated = await _repository.updateTask(id, fields);
    if (updated == null) {
      return Response.notFound(jsonEncode({'error': 'task_not_found'}));
    }

    _eventHub.broadcast({
      'type': 'task.updated',
      'task': updated.toJson(),
      'familyId': updated.familyId,
    });

    return Response.ok(jsonEncode({'task': updated.toJson()}));
  }

  Future<Response> deleteTask(Request request, String id) async {
    final existing = await _repository.getTask(id);
    if (existing == null) {
      return Response.notFound(jsonEncode({'error': 'task_not_found'}));
    }

    await _repository.deleteTask(id);
    _eventHub.broadcast({
      'type': 'task.deleted',
      'taskId': id,
      'familyId': existing.familyId,
    });
    return Response(204);
  }

  Future<Response> assignTask(Request request, String id) async {
    final payload = await _decodeJsonBody(request);
    final userId = payload['userId'] as String?;
    if (userId == null) {
      return Response(400, body: jsonEncode({'error': 'userId is required'}));
    }

    final task = await _repository.assignTask(id, userId);
    if (task == null) {
      return Response.notFound(jsonEncode({'error': 'task_not_found'}));
    }

    _eventHub.broadcast({
      'type': 'task.assigned',
      'task': task.toJson(),
      'familyId': task.familyId,
    });

    return Response.ok(jsonEncode({'task': task.toJson()}));
  }

  Future<Response> broadcastUpdate(Request request, String id) async {
    final payload = await _decodeJsonBody(request);
    final familyId = payload['familyId'] as String?;
    if (familyId == null || familyId.isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'familyId is required'}));
    }

    final event = <String, dynamic>{
      'type': 'task.updated',
      'taskId': id,
      'familyId': familyId,
      if (payload['task'] != null) 'task': payload['task'],
      if (payload['changes'] != null) 'changes': payload['changes'],
    };

    _eventHub.broadcast(event);

    return Response.ok(jsonEncode({'status': 'broadcasted'}));
  }

  Future<Response> completeByQrPayload(Request request) async {
    final payload = await _decodeJsonBody(request);
    final qrPayload = payload['payload'] as String?;
    if (qrPayload == null) {
      return Response(400, body: jsonEncode({'error': 'payload is required'}));
    }

    final task = await _repository.completeTaskByQrPayload(qrPayload);
    if (task == null) {
      return Response.notFound(jsonEncode({'error': 'task_not_found'}));
    }

    _eventHub.broadcast({
      'type': 'task.completed',
      'task': task.toJson(),
      'familyId': task.familyId,
    });

    return Response.ok(jsonEncode({'task': task.toJson()}));
  }

  Future<Map<String, dynamic>> _decodeJsonBody(Request request) async {
    final body = await request.readAsString();
    if (body.isEmpty) return {};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Invalid JSON payload');
  }

  DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);

  }
}
