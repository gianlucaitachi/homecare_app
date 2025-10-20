import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/core/di/service_locator.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/cubit/task_detail_cubit.dart';
import 'package:homecare_app/features/tasks/presentation/cubit/task_detail_state.dart';
import 'package:homecare_app/features/tasks/presentation/cubit/task_form_cubit.dart';
import 'package:homecare_app/features/tasks/presentation/screens/task_form_screen.dart';
import 'package:homecare_app/features/tasks/presentation/widgets/task_qr_scanner_sheet.dart';
import 'package:homecare_app/features/tasks/presentation/widgets/task_qr_view.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    final taskBloc = context.read<TaskBloc>();
    return BlocProvider(
      create: (_) => TaskDetailCubit(
        repository: sl<TaskRepository>(),
        taskBloc: taskBloc,
        taskId: taskId,
      )..load(),
      child: _TaskDetailView(taskId: taskId),
    );
  }
}

class _TaskDetailView extends StatelessWidget {
  const _TaskDetailView({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaskDetailCubit, TaskDetailState>(
      listener: (context, state) {
        if (state.actionStatus == TaskDetailActionStatus.success &&
            state.actionMessage != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.actionMessage!)));
        } else if (state.actionStatus == TaskDetailActionStatus.failure &&
            state.actionMessage != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.actionMessage!)));
        }
      },
      builder: (context, state) {
        switch (state.status) {
          case TaskDetailStatus.initial:
          case TaskDetailStatus.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case TaskDetailStatus.failure:
            return Scaffold(
              appBar: AppBar(title: const Text('Task detail')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(state.errorMessage ?? 'Unable to load task'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context.read<TaskDetailCubit>().load(),
                        child: const Text('Retry'),
                      )
                    ],
                  ),
                ),
              ),
            );
          case TaskDetailStatus.loaded:
            final task = state.task!;
            return Scaffold(
              appBar: AppBar(
                title: Text(task.title),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _openEdit(context, task),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(
                          label: Text(task.status.label),
                          avatar: Icon(
                            task.isCompleted ? Icons.check_circle : Icons.schedule,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (task.assignedUserId != null)
                          Chip(label: Text('Assigned: ${task.assignedUserId}')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (task.description != null && task.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(task.description!),
                      ),
                    Row(
                      children: [
                        const Icon(Icons.family_restroom, size: 18),
                        const SizedBox(width: 8),
                        Text('Family: ${task.familyId}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          task.dueDate == null
                              ? 'No due date'
                              : 'Due: ${MaterialLocalizations.of(context).formatMediumDate(task.dueDate!)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Task QR Code', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TaskQrView(qrImageBase64: task.qrImageBase64),
                    const SizedBox(height: 24),
                    if (!task.isCompleted)
                      ElevatedButton.icon(
                        onPressed: () => _scanToComplete(context),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan QR to complete'),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _assignCaregiver(context),
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Assign caregiver'),
                    ),
                  ],
                ),
              ),
            );
        }
      },
    );
  }

  Future<void> _openEdit(BuildContext context, Task task) async {
    final repository = sl<TaskRepository>();
    final taskBloc = context.read<TaskBloc>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => TaskFormCubit(
            repository: repository,
            taskBloc: taskBloc,
            initialTask: task,
          ),
          child: TaskFormScreen(initialTask: task),
        ),
      ),
    );
    if (context.mounted) {
      context.read<TaskDetailCubit>().load();
    }
  }

  Future<void> _scanToComplete(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => TaskQrScannerSheet(
        onDetected: (code) {
          context.read<TaskDetailCubit>().completeWithQr(code);
        },
      ),
    );
  }

  Future<void> _assignCaregiver(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Assign caregiver'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Caregiver user ID'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );
    if (result != null && result.isNotEmpty && context.mounted) {
      await context.read<TaskDetailCubit>().assignTo(result);
    }
  }
}
