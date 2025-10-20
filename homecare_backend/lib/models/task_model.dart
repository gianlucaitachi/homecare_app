enum TaskStatus { pending, inProgress, completed;

  static TaskStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return TaskStatus.pending;
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      default:
        return TaskStatus.pending;
    }
  }

  String get value => switch (this) {
        TaskStatus.pending => 'pending',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.completed => 'completed',
      };
}

class Task {
  Task({
    required this.id,
    required this.familyId,
    this.assignedUserId,
    required this.title,
    this.description,
    required this.status,
    this.dueDate,
    required this.qrPayload,
    required this.qrImageBase64,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String familyId;
  final String? assignedUserId;
  final String title;
  final String? description;
  final TaskStatus status;
  final DateTime? dueDate;
  final String qrPayload;
  final String qrImageBase64;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  factory Task.fromRow(Map<String, dynamic> row) {
    return Task(
      id: row['id'] as String,
      familyId: row['family_id'] as String,
      assignedUserId: row['assigned_user_id'] as String?,
      title: row['title'] as String,
      description: row['description'] as String?,
      status: TaskStatus.fromString(row['status'] as String),
      dueDate: row['due_date'] as DateTime?,
      qrPayload: row['qr_payload'] as String,
      qrImageBase64: row['qr_image_base64'] as String,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['updated_at'] as DateTime,
      completedAt: row['completed_at'] as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyId': familyId,
        'assignedUserId': assignedUserId,
        'title': title,
        'description': description,
        'status': status.value,
        'dueDate': dueDate?.toIso8601String(),
        'qrPayload': qrPayload,
        'qrImageBase64': qrImageBase64,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  Task copyWith({
    String? id,
    String? familyId,
    String? assignedUserId,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    String? qrPayload,
    String? qrImageBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return Task(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      qrPayload: qrPayload ?? this.qrPayload,
      qrImageBase64: qrImageBase64 ?? this.qrImageBase64,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
