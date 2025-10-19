
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                // Sửa: Dùng state.message
                SnackBar(content: Text(state.message)),
              );
          } else if (state is Authenticated) { // Sửa: Dùng Authenticated
            // Khi đăng ký thành công, thông báo và tự động điều hướng về màn hình đăng nhập
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registration Successful! You can now log in.')),
            );
            Navigator.of(context).pop(); // Quay lại màn hình trước đó (LoginScreen)
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  keyboardType: TextInputType.name,
                ),
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
                if (state is AuthLoading)
                  const ElevatedButton(
                    onPressed: null,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      if (_nameController.text.isNotEmpty &&
                          _emailController.text.isNotEmpty &&
                          _passwordController.text.isNotEmpty) {
                        context.read<AuthBloc>().add(
                              // Sửa: Dùng RegisterRequested
                              RegisterRequested(
                                name: _nameController.text.trim(),
                                email: _emailController.text.trim(),
                                password: _passwordController.text,
                              ),
                            );
                      }
                    },
                    child: const Text('Register'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
