import 'package:flutter/material.dart';
import 'package:homecare_app/features/auth/domain/entities/auth_session.dart';
import 'package:homecare_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:homecare_app/features/dashboard/presentation/dashboard_module.dart';
import 'package:homecare_app/features/profile/presentation/profile_screen.dart';
import 'package:homecare_app/features/tasks/presentation/tasks_module.dart';

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({super.key, required this.session});

  final AuthSession session;

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  int _currentIndex = 0;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.checklist_outlined),
      selectedIcon: Icon(Icons.checklist),
      label: 'Tasks',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat),
      label: 'Chat',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  List<Widget> get _pages {
    final user = widget.session.user;
    return [
      DashboardModule(
        key: const PageStorageKey('dashboard'),
        user: user,
        onViewTasks: () => _onDestinationSelected(1),
        onOpenChat: () => _onDestinationSelected(2),
      ),
      TasksModule(
        key: const PageStorageKey('tasks'),
        familyId: user.familyId,
      ),
      ChatScreen(
        key: const PageStorageKey('chat'),
        familyId: user.familyId,
        currentUserId: user.id,
      ),
      ProfileScreen(
        key: const PageStorageKey('profile'),
        session: widget.session,
      ),
    ];
  }

  void _onDestinationSelected(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: _destinations,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}
