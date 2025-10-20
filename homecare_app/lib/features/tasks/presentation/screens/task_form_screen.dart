import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    return BlocListener<TaskFormCubit, TaskFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == TaskFormStatus.success) {
          Navigator.of(context).pop(state.result);
        } else if (state.status == TaskFormStatus.failure && state.errorMessage != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
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
                TextFormField(
                  controller: _assignedController,
                  decoration:
                      const InputDecoration(labelText: 'Assigned caregiver ID (optional)'),
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
      assignedUserId:
          _assignedController.text.isEmpty ? null : _assignedController.text,
    );
  }
}
