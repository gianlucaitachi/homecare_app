import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/core/di/service_locator.dart';
import 'package:homecare_app/features/members/presentation/bloc/members_bloc.dart';
import 'package:homecare_app/features/members/presentation/bloc/members_event.dart';
import 'package:homecare_app/features/members/presentation/bloc/members_state.dart';
import 'package:homecare_app/features/members/presentation/widgets/member_selector_dialog.dart';
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
  const TaskDetailScreen({super.key, required this.taskId, this.familyId});

  final String taskId;
  final String? familyId;

  @override
  Widget build(BuildContext context) {
    final taskBloc = context.read<TaskBloc>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final bloc = sl<MembersBloc>(param1: familyId);
            if (familyId != null) {
              bloc.add(MembersRequested(familyId: familyId));
            }
            return bloc;
          },
        ),
        BlocProvider(
          create: (_) {
            final cubit = TaskDetailCubit(
              repository: sl<TaskRepository>(),
              taskBloc: taskBloc,
              taskId: taskId,
            );
            unawaited(cubit.load());
            return cubit;
          },
        ),
      ],
      child: _TaskDetailView(initialFamilyId: familyId),
    );
  }
}

class _TaskDetailView extends StatefulWidget {
  const _TaskDetailView({this.initialFamilyId});

  final String? initialFamilyId;

  @override
  State<_TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<_TaskDetailView> {
  String? _membersLoadedFor;

  @override
  void initState() {
    super.initState();
    _membersLoadedFor = widget.initialFamilyId;
  }

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

        if (state.status == TaskDetailStatus.loaded) {
          final task = state.task;
          final familyId = task?.familyId;
          if (familyId != null && familyId.isNotEmpty && _membersLoadedFor != familyId) {
            context.read<MembersBloc>().add(MembersRequested(familyId: familyId, silent: true));
            _membersLoadedFor = familyId;
          }
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
                          BlocBuilder<MembersBloc, MembersState>(
                            builder: (context, membersState) {
                              final member =
                                  membersState.memberById(task.assignedUserId);
                              final label = member != null
                                  ? 'Assigned: ${member.name}'
                                  : 'Assigned: ${task.assignedUserId}';
                              return Chip(label: Text(label));
                            },
                          ),
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
    final membersBloc = context.read<MembersBloc>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => TaskFormCubit(
                repository: repository,
                taskBloc: taskBloc,
                initialTask: task,
              ),
            ),
            BlocProvider.value(value: membersBloc),
          ],
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
    final membersBloc = context.read<MembersBloc>();
    final detailState = context.read<TaskDetailCubit>().state;
    final familyId = membersBloc.familyId ?? detailState.task?.familyId;
    if (familyId == null || familyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family information missing. Unable to load caregivers.')),
      );
      return;
    }

    final selection = await showMemberSelectorDialog(
      context,
      familyId: familyId,
      title: 'Assign caregiver',
    );

    if (!context.mounted || selection == null) {
      return;
    }

    final member = selection.member;
    if (member == null) {
      return;
    }

    await context.read<TaskDetailCubit>().assignTo(member.id);
  }
}
