import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../db/postgres_client.dart';
import '../models/task_model.dart';
import '../services/task_qr_service.dart';

abstract class TaskRepository {
  Future<List<Task>> listTasks({required String familyId});
  Future<Task?> getTask(String id);
  Future<Task> createTask({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  });
  Future<Task?> updateTask(String id, Map<String, dynamic> fields);
  Future<void> deleteTask(String id);
  Future<Task?> assignTask(String id, String userId);
  Future<Task?> completeTaskByQrPayload(String payload);
}

class PostgresTaskRepository implements TaskRepository {
  PostgresTaskRepository(
    this._db, {
    TaskQrService? qrService,
    Uuid? uuid,
  })  : _qrService = qrService ?? TaskQrService(),
        _uuid = uuid ?? const Uuid();

  final PostgresClient _db;
  final TaskQrService _qrService;
  final Uuid _uuid;

  PostgreSQLConnection get _conn => _db.raw;

  @override
  Future<List<Task>> listTasks({required String familyId}) async {
    final results = await _conn.mappedResultsQuery(
      'SELECT * FROM tasks WHERE family_id = @familyId ORDER BY due_date NULLS LAST, created_at DESC',
      substitutionValues: {'familyId': familyId},
    );

    return results
        .map((row) => Task.fromRow(row['tasks']!))
        .toList(growable: false);
  }

  @override
  Future<Task?> getTask(String id) async {
    final results = await _conn.mappedResultsQuery(
      'SELECT * FROM tasks WHERE id = @id LIMIT 1',
      substitutionValues: {'id': id},
    );
    if (results.isEmpty) return null;
    return Task.fromRow(results.first['tasks']!);
  }

  @override
  Future<Task> createTask({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  }) async {
    final id = _uuid.v4();
    final qrResult = _qrService.generate(id);

    final results = await _conn.mappedResultsQuery(
      'INSERT INTO tasks (id, family_id, assigned_user_id, title, description, due_date, qr_payload, qr_image_base64) '
      'VALUES (@id, @familyId, @assignedUserId, @title, @description, @dueDate, @qrPayload, @qrImage) '
      'RETURNING *',
      substitutionValues: {
        'id': id,
        'familyId': familyId,
        'assignedUserId': assignedUserId,
        'title': title,
        'description': description,
        'dueDate': dueDate,
        'qrPayload': qrResult.payload,
        'qrImage': qrResult.imageDataUri,
      },
    );

    return Task.fromRow(results.first['tasks']!);
  }

  @override
  Future<Task?> updateTask(String id, Map<String, dynamic> fields) async {
    if (fields.isEmpty) {
      return getTask(id);
    }

    final setClauses = <String>[];
    final values = <String, dynamic>{'id': id};

    fields.forEach((column, value) {
      setClauses.add('$column = @$column');
      values[column] = value;
    });

    final query = 'UPDATE tasks SET ${setClauses.join(', ')} WHERE id = @id RETURNING *';

    final results = await _conn.mappedResultsQuery(query, substitutionValues: values);
    if (results.isEmpty) return null;
    return Task.fromRow(results.first['tasks']!);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _conn.query('DELETE FROM tasks WHERE id = @id', substitutionValues: {'id': id});
  }

  @override
  Future<Task?> assignTask(String id, String userId) async {
    final results = await _conn.mappedResultsQuery(
      'UPDATE tasks SET assigned_user_id = @userId, status = @status WHERE id = @id RETURNING *',
      substitutionValues: {
        'id': id,
        'userId': userId,
        'status': TaskStatus.inProgress.value,
      },
    );
    if (results.isEmpty) return null;
    return Task.fromRow(results.first['tasks']!);
  }

  @override
  Future<Task?> completeTaskByQrPayload(String payload) async {
    final results = await _conn.mappedResultsQuery(
      'UPDATE tasks SET status = @status, completed_at = NOW() WHERE qr_payload = @payload RETURNING *',
      substitutionValues: {
        'payload': payload,
        'status': TaskStatus.completed.value,
      },
    );
    if (results.isEmpty) return null;
    return Task.fromRow(results.first['tasks']!);
  }
}
