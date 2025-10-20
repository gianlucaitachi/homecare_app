import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../models/task_model.dart';
import '../services/task_qr_service.dart';

abstract class TaskRepository {
  Future<List<Task>> listTasks({required String familyId});
  Future<Task?> getTask(String id, {required String familyId});
  Future<Task> createTask({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  });
  Future<Task?> updateTask(
    String id,
    Map<String, dynamic> fields, {
    required String familyId,
  });

  Future<void> deleteTask(String id, {required String familyId});

  Future<Task?> assignTask(
    String id,
    String userId, {
    required String familyId,
  });

  Future<Task?> completeTaskByQrPayload(
    String payload, {
    required String familyId,
  });
}

class PostgresTaskRepository implements TaskRepository {
  PostgresTaskRepository(
    this._db, {
    TaskQrService? qrService,
    Uuid? uuid,
  })  : _qrService = qrService ?? TaskQrService(),
        _uuid = uuid ?? const Uuid();

  final DatabaseManager _db;
  final TaskQrService _qrService;
  final Uuid _uuid;

  Connection get _conn => _db.conn;

  @override
  Future<List<Task>> listTasks({required String familyId}) async {
    final results = await _conn.execute(
      Sql.named(
        'SELECT * FROM tasks WHERE family_id = @familyId '
        'ORDER BY due_date NULLS LAST, created_at DESC',
      ),
      parameters: {'familyId': familyId},
    );

    return results
        .map((row) => Task.fromRow(row.toColumnMap()))
        .toList(growable: false);
  }

  @override
  Future<Task?> getTask(String id, {required String familyId}) async {
    final results = await _conn.execute(
      Sql.named(
        'SELECT * FROM tasks WHERE id = @id AND family_id = @familyId LIMIT 1',
      ),
      parameters: {
        'id': id,
        'familyId': familyId,
      },
    );
    if (results.isEmpty) return null;
    return Task.fromRow(results.first.toColumnMap());
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

    final results = await _conn.execute(
      Sql.named(
        'INSERT INTO tasks (id, family_id, assigned_user_id, title, description, '
        'due_date, qr_payload, qr_image_base64) '
        'VALUES (@id, @familyId, @assignedUserId, @title, @description, @dueDate, @qrPayload, @qrImage) '
        'RETURNING *',
      ),
      parameters: {
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

    return Task.fromRow(results.first.toColumnMap());
  }

  @override
  Future<Task?> updateTask(
    String id,
    Map<String, dynamic> fields, {
    required String familyId,
  }) async {
    if (fields.isEmpty) {
      return getTask(id, familyId: familyId);
    }

    final setClauses = <String>[];
    final values = <String, dynamic>{
      'id': id,
      'familyId': familyId,
    };

    fields.forEach((column, value) {
      setClauses.add('$column = @$column');
      values[column] = value;
    });

    final query =
        'UPDATE tasks SET ${setClauses.join(', ')} WHERE id = @id AND family_id = @familyId RETURNING *';

    final results = await _conn.execute(
      Sql.named(query),
      parameters: values,
    );
    if (results.isEmpty) return null;
    return Task.fromRow(results.first.toColumnMap());
  }

  @override
  Future<void> deleteTask(String id, {required String familyId}) async {
    await _conn.execute(
      Sql.named('DELETE FROM tasks WHERE id = @id AND family_id = @familyId'),
      parameters: {
        'id': id,
        'familyId': familyId,
      },
      ignoreRows: true,
    );
  }

  @override
  Future<Task?> assignTask(
    String id,
    String userId, {
    required String familyId,
  }) async {
    final results = await _conn.execute(
      Sql.named(
        'UPDATE tasks SET assigned_user_id = @userId, status = @status '
        'WHERE id = @id AND family_id = @familyId RETURNING *',
      ),
      parameters: {
        'id': id,
        'userId': userId,
        'status': TaskStatus.inProgress.value,
        'familyId': familyId,
      },
    );
    if (results.isEmpty) return null;
    return Task.fromRow(results.first.toColumnMap());
  }

  @override
  Future<Task?> completeTaskByQrPayload(
    String payload, {
    required String familyId,
  }) async {
    final results = await _conn.execute(
      Sql.named(
        'UPDATE tasks SET status = @status, completed_at = NOW() '
        'WHERE qr_payload = @payload AND family_id = @familyId RETURNING *',
      ),
      parameters: {
        'payload': payload,
        'status': TaskStatus.completed.value,
        'familyId': familyId,
      },
    );
    if (results.isEmpty) return null;
    return Task.fromRow(results.first.toColumnMap());
  }
}
