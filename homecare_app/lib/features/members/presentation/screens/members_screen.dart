import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/core/di/service_locator.dart';
import 'package:homecare_app/features/members/domain/entities/member.dart';

import '../bloc/members_bloc.dart';
import '../bloc/members_event.dart';
import '../bloc/members_state.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key, required this.familyId});

  final String familyId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<MembersBloc>(param1: familyId)
        ..add(MembersRequested(familyId: familyId)),
      child: const _MembersView(),
    );
  }
}

class _MembersView extends StatelessWidget {
  const _MembersView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final bloc = context.read<MembersBloc>();
              bloc.add(MembersRequested(familyId: bloc.familyId, silent: false));
            },
          ),
        ],
      ),
      body: BlocBuilder<MembersBloc, MembersState>(
        builder: (context, state) {
          switch (state.status) {
            case MembersStatus.initial:
            case MembersStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case MembersStatus.failure:
              return _MembersErrorView(message: state.errorMessage);
            case MembersStatus.success:
              if (state.members.isEmpty) {
                return const _MembersEmptyView();
              }
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<MembersBloc>().add(const MembersRefreshed());
                },
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: state.members.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = state.members[index];
                    return _MemberTile(member: member);
                  },
                ),
              );
          }
        },
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          member.name.isNotEmpty
              ? member.name.characters.first.toUpperCase()
              : member.email.characters.first.toUpperCase(),
        ),
      ),
      title: Text(member.name.isEmpty ? member.email : member.name),
      subtitle: Text('${member.email}\n${member.roleLabel}'),
      isThreeLine: true,
    );
  }
}

class _MembersEmptyView extends StatelessWidget {
  const _MembersEmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No members found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Invite caregivers to join your family to assign tasks and stay in sync.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersErrorView extends StatelessWidget {
  const _MembersErrorView({this.message});

  final String? message;

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
            Text(
              message ?? 'Unable to load family members.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final bloc = context.read<MembersBloc>();
                bloc.add(MembersRequested(familyId: bloc.familyId, silent: false));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
