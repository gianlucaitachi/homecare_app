import 'package:homecare_app/features/tasks/domain/entities/task.dart';

class TaskModel extends Task {
  const TaskModel({
    required super.id,
    required super.familyId,
    required super.title,
    super.description,
    required super.status,
    super.dueDate,
    super.assignedUserId,
    required super.qrPayload,
    required super.qrImageBase64,
    required super.createdAt,
    required super.updatedAt,
    super.completedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      familyId: json['familyId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: TaskStatus.fromString(json['status'] as String? ?? 'pending'),
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
      assignedUserId: json['assignedUserId'] as String?,
      qrPayload: json['qrPayload'] as String,
      qrImageBase64: json['qrImageBase64'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      completedAt:
          json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyId': familyId,
        'title': title,
        'description': description,
        'status': status.apiValue,
        'dueDate': dueDate?.toIso8601String(),
        'assignedUserId': assignedUserId,
        'qrPayload': qrPayload,
        'qrImageBase64': qrImageBase64,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  static List<TaskModel> fromJsonList(List<dynamic> data) =>
      data.map((item) => TaskModel.fromJson(item as Map<String, dynamic>)).toList();
}
