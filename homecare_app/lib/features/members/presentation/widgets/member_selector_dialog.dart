import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/features/members/domain/entities/member.dart';

import '../bloc/members_bloc.dart';
import '../bloc/members_event.dart';
import '../bloc/members_state.dart';

Future<({Member? member, bool cleared})?> showMemberSelectorDialog(
  BuildContext context, {
  String? familyId,
  bool allowClear = false,
  String title = 'Select caregiver',
}) {
  final bloc = context.read<MembersBloc>();
  final shouldSilence = bloc.state.status == MembersStatus.success;
  if (familyId != null && familyId.isNotEmpty) {
    bloc.add(MembersRequested(familyId: familyId, silent: shouldSilence));
  } else if (bloc.familyId != null && bloc.state.status == MembersStatus.initial) {
    bloc.add(MembersRequested(familyId: bloc.familyId));
  }

  return showDialog<({Member? member, bool cleared})?>(
    context: context,
    builder: (dialogContext) {
      return BlocProvider.value(
        value: bloc,
        child: _MemberSelectorDialog(
          allowClear: allowClear,
          title: title,
        ),
      );
    },
  );
}

class _MemberSelectorDialog extends StatelessWidget {
  const _MemberSelectorDialog({required this.allowClear, required this.title});

  final bool allowClear;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: BlocBuilder<MembersBloc, MembersState>(
          builder: (context, state) {
            switch (state.status) {
              case MembersStatus.initial:
              case MembersStatus.loading:
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              case MembersStatus.failure:
                return _MemberError(message: state.errorMessage);
              case MembersStatus.success:
                if (state.members.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No caregivers found for this family.'),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.members.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final member = state.members[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(member.name.isNotEmpty
                              ? member.name.characters.first.toUpperCase()
                              : '?'),
                        ),
                        title: Text(member.name.isEmpty ? member.email : member.name),
                        subtitle: Text('${member.email}\n${member.roleLabel}'),
                        isThreeLine: true,
                        onTap: () => Navigator.of(context).pop((member: member, cleared: false)),
                      );
                    },
                  ),
                );
            }
          },
        ),
      ),
      actions: [
        if (allowClear)
          TextButton(
            onPressed: () => Navigator.of(context).pop((member: null, cleared: true)),
            child: const Text('Clear assignment'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _MemberError extends StatelessWidget {
  const _MemberError({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
        const SizedBox(height: 12),
        Text(
          message ?? 'Unable to load family members.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {
            final bloc = context.read<MembersBloc>();
            bloc.add(MembersRequested(familyId: bloc.familyId, silent: false));
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
