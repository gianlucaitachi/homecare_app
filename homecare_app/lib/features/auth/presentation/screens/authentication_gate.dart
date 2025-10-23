import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/core/di/service_locator.dart';
import 'package:homecare_app/features/app_shell/presentation/authenticated_shell.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart'
    show AuthBloc, AuthState, Authenticated, Unauthenticated, AuthFailure;
import 'package:homecare_app/features/auth/presentation/screens/login_screen.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';

class AuthenticationGate extends StatelessWidget {
  const AuthenticationGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return BlocProvider(
            create: (_) => TaskBloc(notificationService: sl()),
            child: AuthenticatedShell(session: state.session),
          );
        } else if (state is Unauthenticated || state is AuthFailure) {
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
