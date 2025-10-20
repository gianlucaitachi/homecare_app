import 'package:flutter/material.dart';

import 'screens/task_list_screen.dart';

class TasksModule extends StatelessWidget {
  const TasksModule({super.key, required this.familyId});

  final String familyId;

  @override
  Widget build(BuildContext context) {
    return TaskListScreen(familyId: familyId);
  }
}
