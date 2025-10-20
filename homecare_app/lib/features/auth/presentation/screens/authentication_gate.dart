import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:homecare_app/features/auth/presentation/screens/login_screen.dart';
import 'package:homecare_app/features/chat/presentation/screens/chat_screen.dart';

// Placeholder cho màn hình chính của bạn
class AuthenticationGate extends StatelessWidget {
  const AuthenticationGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          // Người dùng đã đăng nhập, hiển thị màn hình chính
          return const ChatScreen(
            familyId: 'demo-family',
            currentUserId: 'demo-user',
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
