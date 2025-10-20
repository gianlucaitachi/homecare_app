import 'package:dio/dio.dart';

import '../../domain/entities/task.dart';
import '../models/task_model.dart';

abstract class TaskRemoteDataSource {
  Future<List<TaskModel>> fetchTasks({String? familyId});
  Future<TaskModel> fetchTask(String id);
  Future<TaskModel> createTask({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  });
  Future<TaskModel> updateTask(String id, Map<String, dynamic> payload);
  Future<void> deleteTask(String id);
  Future<TaskModel> assignTask(String id, String userId);
  Future<TaskModel> completeTaskByQrPayload(String payload);
}

class TaskRemoteDataSourceImpl implements TaskRemoteDataSource {
  TaskRemoteDataSourceImpl({required Dio dio, required String apiBaseUrl})
      : _dio = dio,
        _apiBaseUrl = apiBaseUrl;

  final Dio _dio;
  final String _apiBaseUrl;

  String get _tasksBase => '$_apiBaseUrl/tasks';

  @override
  Future<TaskModel> assignTask(String id, String userId) async {
    final response = await _dio.post('$_tasksBase/$id/assign', data: {'userId': userId});
    return TaskModel.fromJson(response.data['task'] as Map<String, dynamic>);
  }

  @override
  Future<TaskModel> completeTaskByQrPayload(String payload) async {
    final response = await _dio.post('$_tasksBase/complete-qr', data: {'payload': payload});
    return TaskModel.fromJson(response.data['task'] as Map<String, dynamic>);
  }

  @override
  Future<TaskModel> createTask({
    required String familyId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? assignedUserId,
  }) async {
    final payload = <String, dynamic>{
      'familyId': familyId,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'assignedUserId': assignedUserId,
    }..removeWhere((key, value) => value == null);

    final response = await _dio.post(_tasksBase, data: payload);
    return TaskModel.fromJson(response.data['task'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteTask(String id) async {
    await _dio.delete('$_tasksBase/$id');
  }

  @override
  Future<TaskModel> fetchTask(String id) async {
    final response = await _dio.get('$_tasksBase/$id');
    return TaskModel.fromJson(response.data['task'] as Map<String, dynamic>);
  }

  @override
  Future<List<TaskModel>> fetchTasks({String? familyId}) async {
    final response = await _dio.get(
      _tasksBase,
      queryParameters: familyId == null ? null : {'familyId': familyId},
    );
    final data = response.data['tasks'] as List<dynamic>;
    return TaskModel.fromJsonList(data);
  }

  @override
  Future<TaskModel> updateTask(String id, Map<String, dynamic> payload) async {
    final response = await _dio.put('$_tasksBase/$id', data: payload);
    return TaskModel.fromJson(response.data['task'] as Map<String, dynamic>);
  }
}
