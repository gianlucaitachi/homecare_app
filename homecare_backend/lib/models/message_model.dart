class Message {
  const Message({
    required this.id,
    required this.familyId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  factory Message.fromRow(Map<String, dynamic> row) {
    return Message(
      id: row['id'] as String,
      familyId: row['family_id'] as String,
      senderId: row['sender_id'] as String,
      content: row['content'] as String,
      createdAt: (row['created_at'] as DateTime).toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyId': familyId,
        'senderId': senderId,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };
}
