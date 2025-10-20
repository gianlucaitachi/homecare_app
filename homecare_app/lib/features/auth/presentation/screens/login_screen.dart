
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/core/di/service_locator.dart';
import 'package:homecare_app/core/notifications/notification_service.dart';
import 'package:homecare_app/features/app_shell/presentation/authenticated_shell.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:homecare_app/features/auth/presentation/screens/register_screen.dart';
import 'package:homecare_app/features/tasks/presentation/bloc/task_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                // Sửa: Dùng state.message thay cho state.error
                SnackBar(content: Text(state.message)),
              );
          } else if (state is Authenticated) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Login Successful!')),
              );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (_) => TaskBloc(
                    notificationService: sl<NotificationService>(),
                  ),
                  child: AuthenticatedShell(session: state.session),
                ),
              ),
              (route) => false,
            );
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                // Hiển thị loading indicator khi state là AuthLoading
                if (state is AuthLoading)
                  const ElevatedButton(
                    onPressed: null,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
                        context.read<AuthBloc>().add(
                              // Sửa: Dùng LoginRequested thay cho AuthLoginRequested
                              LoginRequested(
                                email: _emailController.text.trim(),
                                password: _passwordController.text,
                              ),
                            );
                      }
                    },
                    child: const Text('Login'),
                  ),
                const SizedBox(height: 10),
                // Nút điều hướng đến màn hình đăng ký
                TextButton(
                  onPressed: () {
                    // Chuyển hướng không bị loading đè lên
                    if (state is! AuthLoading) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    }
                  },
                  child: const Text('Don\'t have an account? Register'),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
