import 'package:flutter/material.dart';

import 'package:homecare_app/features/auth/domain/entities/user.dart';

class DashboardModule extends StatelessWidget {
  const DashboardModule({
    super.key,
    required this.user,
    required this.onViewTasks,
    required this.onOpenChat,
    required this.onViewMembers,
  });

  final User user;
  final VoidCallback onViewTasks;
  final VoidCallback onOpenChat;
  final VoidCallback onViewMembers;

  @override
  Widget build(BuildContext context) {
    final firstName = user.name.trim().split(' ').first;
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $firstName'),
      ),
      body: _DashboardOverview(
        user: user,
        onViewTasks: onViewTasks,
        onOpenChat: onOpenChat,
        onViewMembers: onViewMembers,
      ),
    );
  }
}

class _DashboardOverview extends StatelessWidget {
  const _DashboardOverview({
    required this.user,
    required this.onViewTasks,
    required this.onOpenChat,
    required this.onViewMembers,
  });

  final User user;
  final VoidCallback onViewTasks;
  final VoidCallback onOpenChat;
  final VoidCallback onViewMembers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          color: colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${user.name}!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Here\'s a quick overview of your family care hub.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Quick actions',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.checklist),
                title: const Text('Review care tasks'),
                subtitle: const Text('See assignments and create new tasks'),
                onTap: onViewTasks,
                trailing: const Icon(Icons.chevron_right),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('View family members'),
                subtitle: const Text('See caregivers and their roles'),
                onTap: onViewMembers,
                trailing: const Icon(Icons.chevron_right),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('Open family chat'),
                subtitle: const Text('Coordinate with caregivers in real time'),
                onTap: onOpenChat,
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Family profile',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(user.name),
                subtitle: Text(user.email),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.family_restroom),
                title: const Text('Family ID'),
                subtitle: Text(user.familyId),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
