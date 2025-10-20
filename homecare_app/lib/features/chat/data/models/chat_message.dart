class ChatMessage {
  const ChatMessage({
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

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      familyId: json['familyId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
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
