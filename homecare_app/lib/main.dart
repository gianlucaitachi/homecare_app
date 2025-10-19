import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/core/di/service_locator.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:homecare_app/features/auth/presentation/screens/authentication_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Thiết lập tất cả các dependency chỉ với một dòng lệnh.
  await setupDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Cung cấp AuthBloc cho cây widget.
    // sl<AuthBloc>() sẽ yêu cầu và nhận một thực thể AuthBloc từ GetIt.
    return BlocProvider<AuthBloc>(
      create: (context) => sl<AuthBloc>()..add(AuthCheckRequested()),
      child: MaterialApp(
        title: 'HomeCare',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const AuthenticationGate(),
      ),
    );
  }
}
