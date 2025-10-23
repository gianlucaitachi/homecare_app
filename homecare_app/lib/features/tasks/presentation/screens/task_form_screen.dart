import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/features/members/domain/entities/member.dart';
import 'package:homecare_app/features/members/presentation/bloc/members_bloc.dart';
import 'package:homecare_app/features/members/presentation/bloc/members_state.dart';
import 'package:homecare_app/features/members/presentation/widgets/member_selector_dialog.dart';
import 'package:homecare_app/features/tasks/domain/entities/task.dart';
import 'package:homecare_app/features/tasks/presentation/cubit/task_form_cubit.dart';
import 'package:homecare_app/features/tasks/presentation/cubit/task_form_state.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.initialTask, this.initialFamilyId});

  final Task? initialTask;
  final String? initialFamilyId;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _familyController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _assignedController;
  DateTime? _selectedDueDate;
  String? _selectedMemberId;

  TaskFormCubit get _cubit => context.read<TaskFormCubit>();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTask;
    final familyId = initial?.familyId ?? widget.initialFamilyId ?? '';
    _familyController = TextEditingController(text: familyId);
    _titleController = TextEditingController(text: initial?.title ?? '');
    _descriptionController = TextEditingController(text: initial?.description ?? '');
    _assignedController = TextEditingController(text: initial?.assignedUserId ?? '');
    _selectedMemberId = initial?.assignedUserId;
    _selectedDueDate = initial?.dueDate;
  }

  @override
  void dispose() {
    _familyController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _assignedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _cubit.isEditing;
    return MultiBlocListener(
      listeners: [
        BlocListener<TaskFormCubit, TaskFormState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == TaskFormStatus.success) {
              Navigator.of(context).pop(state.result);
            } else if (state.status == TaskFormStatus.failure && state.errorMessage != null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            }
          },
        ),
        BlocListener<MembersBloc, MembersState>(
          listenWhen: (previous, current) =>
              previous.status != current.status && current.status == MembersStatus.success,
          listener: (context, state) {
            final selectedId = _selectedMemberId;
            if (selectedId == null) {
              return;
            }
            final member = state.memberById(selectedId);
            if (member != null && _assignedController.text != member.name) {
              setState(() {
                _assignedController.text = member.name;
              });
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit task' : 'Create task'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _familyController,
                  decoration: const InputDecoration(labelText: 'Family ID'),
                  enabled: !isEditing,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Family ID is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                BlocBuilder<MembersBloc, MembersState>(
                  builder: (context, membersState) {
                    final selectedId = _selectedMemberId;
                    final selectedMember = membersState.memberById(selectedId);
                    final helperText = selectedMember != null
                        ? '${selectedMember.email} • ${selectedMember.roleLabel}'
                        : selectedId != null
                            ? 'Assigned to user ID: $selectedId'
                            : 'Tap to choose a caregiver from your family';
                    final suffixIcon = membersState.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : selectedId != null
                            ? IconButton(
                                tooltip: 'Clear caregiver',
                                onPressed: _clearMemberSelection,
                                icon: const Icon(Icons.clear),
                              )
                            : const Icon(Icons.people_outline);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _assignedController,
                          readOnly: true,
                          enableInteractiveSelection: false,
                          decoration: InputDecoration(
                            labelText: 'Assigned caregiver (optional)',
                            helperText: helperText,
                            suffixIcon: suffixIcon,
                          ),
                          onTap: () => _openMemberSelector(context),
                        ),
                        if (membersState.status == MembersStatus.failure &&
                            membersState.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              membersState.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDueDate == null
                            ? 'No due date'
                            : 'Due date: ${MaterialLocalizations.of(context).formatMediumDate(_selectedDueDate!)}',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDueDate ?? now,
                          firstDate: now.subtract(const Duration(days: 1)),
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _selectedDueDate = picked);
                        }
                      },
                      icon: const Icon(Icons.date_range),
                      label: const Text('Pick due date'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                BlocBuilder<TaskFormCubit, TaskFormState>(
                  builder: (context, state) {
                    final isLoading = state.status == TaskFormStatus.submitting;
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(isEditing ? 'Save changes' : 'Create task'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _cubit.submit(
      familyId: _familyController.text,
      title: _titleController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      dueDate: _selectedDueDate,
      assignedUserId: _selectedMemberId,
    );
  }

  Future<void> _openMemberSelector(BuildContext context) async {
    final bloc = context.read<MembersBloc>();
    final manualFamilyId = _familyController.text.trim();
    final effectiveFamilyId =
        manualFamilyId.isEmpty ? (bloc.familyId ?? '') : manualFamilyId;

    if (effectiveFamilyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a family ID to choose caregivers.')),
      );
      return;
    }

    final selection = await showMemberSelectorDialog(
      context,
      familyId: effectiveFamilyId,
      allowClear: true,
    );

    if (!mounted || selection == null) {
      return;
    }

    if (selection.cleared) {
      _clearMemberSelection();
    } else if (selection.member != null) {
      _setSelectedMember(selection.member!);
    }
  }

  void _setSelectedMember(Member member) {
    setState(() {
      _selectedMemberId = member.id;
      _assignedController.text = member.name;
    });
  }

  void _clearMemberSelection() {
    setState(() {
      _selectedMemberId = null;
      _assignedController.text = '';
    });
  }
}
