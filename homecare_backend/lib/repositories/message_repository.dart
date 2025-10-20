import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../models/message_model.dart';

abstract class MessageRepository {
  Future<List<Message>> getMessagesByFamily(String familyId);

  Future<Message> createMessage({
    required String familyId,
    required String senderId,
    required String content,
  });
}

class PostgresMessageRepository implements MessageRepository {
  PostgresMessageRepository(this._db, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final DatabaseManager _db;
  final Uuid _uuid;

  Connection get _conn => _db.conn;

  @override
  Future<List<Message>> getMessagesByFamily(String familyId) async {
    final result = await _conn.execute(
      Sql.named(
        'SELECT id, family_id, sender_id, content, created_at '
        'FROM messages WHERE family_id = @familyId ORDER BY created_at ASC',
      ),
      parameters: {'familyId': familyId},
    );

    return result
        .map((row) => Message.fromRow(row.toColumnMap()))
        .toList(growable: false);
  }

  @override
  Future<Message> createMessage({
    required String familyId,
    required String senderId,
    required String content,
  }) async {
    final messageId = _uuid.v4();

    final result = await _conn.execute(
      Sql.named(
        'INSERT INTO messages (id, family_id, sender_id, content) '
        'VALUES (@id, @familyId, @senderId, @content) '
        'RETURNING id, family_id, sender_id, content, created_at',
      ),
      parameters: {
        'id': messageId,
        'familyId': familyId,
        'senderId': senderId,
        'content': content,
      },
    );

    return Message.fromRow(result.first.toColumnMap());
  }
}
