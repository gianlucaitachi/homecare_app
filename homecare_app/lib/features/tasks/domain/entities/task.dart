import 'package:equatable/equatable.dart';

enum TaskStatus { pending, inProgress, completed;

  factory TaskStatus.fromString(String value) {
    switch (value) {
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      default:
        return TaskStatus.pending;
    }
  }

  String get apiValue => switch (this) {
        TaskStatus.pending => 'pending',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.completed => 'completed',
      };

  String get label => switch (this) {
        TaskStatus.pending => 'Pending',
        TaskStatus.inProgress => 'In progress',
        TaskStatus.completed => 'Completed',
      };
}

class Task extends Equatable {
  const Task({
    required this.id,
    required this.familyId,
    required this.title,
    this.description,
    required this.status,
    this.dueDate,
    this.assignedUserId,
    required this.qrPayload,
    required this.qrImageBase64,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String familyId;
  final String title;
  final String? description;
  final TaskStatus status;
  final DateTime? dueDate;
  final String? assignedUserId;
  final String qrPayload;
  final String qrImageBase64;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  bool get isCompleted => status == TaskStatus.completed;

  Task copyWith({
    String? id,
    String? familyId,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? dueDate,
    String? assignedUserId,
    String? qrPayload,
    String? qrImageBase64,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return Task(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      qrPayload: qrPayload ?? this.qrPayload,
      qrImageBase64: qrImageBase64 ?? this.qrImageBase64,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        familyId,
        title,
        description,
        status,
        dueDate,
        assignedUserId,
        qrPayload,
        qrImageBase64,
        createdAt,
        updatedAt,
        completedAt,
      ];
}
