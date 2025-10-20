import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:homecare_app/features/auth/presentation/screens/login_screen.dart';

import 'package:homecare_app/features/tasks/presentation/screens/task_list_screen.dart';

class AuthenticationGate extends StatelessWidget {
  const AuthenticationGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const TaskListScreen();
        } else if (state is AuthUnauthenticated || state is AuthFailure) {
          // Người dùng chưa đăng nhập hoặc có lỗi, hiển thị màn hình đăng nhập
          return const LoginScreen();
        } else {
          // Trạng thái ban đầu hoặc đang tải, hiển thị màn hình chờ
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }
}
