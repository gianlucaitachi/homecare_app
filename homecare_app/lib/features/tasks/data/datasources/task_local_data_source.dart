import 'package:hive/hive.dart';

import '../models/task_model.dart';

abstract class TaskLocalDataSource {
  Future<List<TaskModel>> getTasks(String familyId);
  Future<TaskModel?> getTask(String id);
  Future<void> upsertTask(TaskModel task);
  Future<void> deleteTask(String id);
  Future<void> replaceTasks(String familyId, List<TaskModel> tasks);
}

class TaskLocalDataSourceImpl implements TaskLocalDataSource {
  TaskLocalDataSourceImpl({HiveInterface? hive}) : _hive = hive ?? Hive;

  final HiveInterface _hive;

  static const _indexBoxName = 'tasks_index';

  String _boxName(String familyId) => 'tasks_$familyId';

  Future<Box<Map<dynamic, dynamic>>> _openTaskBox(String familyId) =>
      _hive.openBox<Map<dynamic, dynamic>>(_boxName(familyId));

  Future<Box<String>> _openIndexBox() => _hive.openBox<String>(_indexBoxName);

  Map<String, dynamic> _normalize(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map(
        (key, dynamic entryValue) => MapEntry(key as String, entryValue),
      );
    }
    throw StateError('Unexpected cached value type: ${value.runtimeType}');
  }

  @override
  Future<List<TaskModel>> getTasks(String familyId) async {
    final box = await _openTaskBox(familyId);
    return box.values
        .map((value) => TaskModel.fromJson(_normalize(value)))
        .toList();
  }

  @override
  Future<TaskModel?> getTask(String id) async {
    final indexBox = await _openIndexBox();
    final familyId = indexBox.get(id);
    if (familyId == null) {
      return null;
    }
    final taskBox = await _openTaskBox(familyId);
    final raw = taskBox.get(id);
    if (raw == null) {
      return null;
    }
    return TaskModel.fromJson(_normalize(raw));
  }

  @override
  Future<void> upsertTask(TaskModel task) async {
    final taskBox = await _openTaskBox(task.familyId);
    final indexBox = await _openIndexBox();
    await taskBox.put(task.id, task.toJson());
    await indexBox.put(task.id, task.familyId);
  }

  @override
  Future<void> deleteTask(String id) async {
    final indexBox = await _openIndexBox();
    final familyId = indexBox.get(id);
    if (familyId == null) {
      return;
    }
    final taskBox = await _openTaskBox(familyId);
    await taskBox.delete(id);
    await indexBox.delete(id);
  }

  @override
  Future<void> replaceTasks(String familyId, List<TaskModel> tasks) async {
    final taskBox = await _openTaskBox(familyId);
    final indexBox = await _openIndexBox();
    final desiredIds = tasks.map((task) => task.id).toSet();
    final existingIds = taskBox.keys.whereType<String>().toSet();

    final idsToDelete = existingIds.difference(desiredIds);
    if (idsToDelete.isNotEmpty) {
      await taskBox.deleteAll(idsToDelete);
      await indexBox.deleteAll(idsToDelete);
    }

    if (tasks.isEmpty) {
      return;
    }

    final entries = <String, Map<String, dynamic>>{
      for (final task in tasks) task.id: task.toJson(),
    };
    await taskBox.putAll(entries);
    await indexBox.putAll({
      for (final task in tasks) task.id: familyId,
    });
  }
}
