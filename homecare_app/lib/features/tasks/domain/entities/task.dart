import 'package:equatable/equatable.dart';

class Task extends Equatable {
  const Task({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  @override
  List<Object?> get props => [id, title, description, dueDate];
}
