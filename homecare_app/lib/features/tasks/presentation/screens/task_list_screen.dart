import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/core/di/service_locator.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_list/task_list_bloc.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_list/task_list_event.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_list/task_list_state.dart';
import 'package:homecare_app/features/tasks/presentation/cubit/task_form_cubit.dart';
import 'package:homecare_app/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:homecare_app/features/tasks/presentation/screens/task_form_screen.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key, this.familyId});

  final String? familyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TaskListBloc(
        repository: sl<TaskRepository>(),
        familyId: familyId,
      )..add(TaskListStarted(familyId: familyId)),
      child: const _TaskListView(),
    );
  }
}

class _TaskListView extends StatelessWidget {
  const _TaskListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openCreate(context),
          ),
        ],
      ),
      body: BlocBuilder<TaskListBloc, TaskListState>(
        builder: (context, state) {
          switch (state.status) {
            case TaskListStatus.initial:
            case TaskListStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case TaskListStatus.failure:
              return _ErrorView(message: state.errorMessage ?? 'Failed to load tasks');
            case TaskListStatus.success:
              if (state.tasks.isEmpty) {
                return const _EmptyView();
              }
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<TaskListBloc>().add(const TaskListRefreshRequested());
                },
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: state.tasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final task = state.tasks[index];
                    return _TaskTile(task: task);
                  },
                ),
              );
          }
        },
      ),
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final repository = sl<TaskRepository>();
    final familyId = context.read<TaskListBloc>().familyId;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => TaskFormCubit(repository: repository),
          child: TaskFormScreen(initialFamilyId: familyId),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (task.status) {
      TaskStatus.pending => Colors.orange,
      TaskStatus.inProgress => Colors.blue,
      TaskStatus.completed => Colors.green,
    };
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.15),
        child: Icon(
          task.isCompleted ? Icons.check : Icons.schedule,
          color: statusColor,
        ),
      ),
      title: Text(task.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status: ${task.status.label}'),
          if (task.assignedUserId != null)
            Text('Assigned to: ${task.assignedUserId}'),
          if (task.dueDate != null)
            Text('Due: ${MaterialLocalizations.of(context).formatShortDate(task.dueDate!)}'),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(taskId: task.id),
          ),
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No tasks yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Tap + to create a task for your family'),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                context.read<TaskListBloc>().add(const TaskListStarted());
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
