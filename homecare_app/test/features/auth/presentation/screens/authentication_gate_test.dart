import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/features/app_shell/presentation/authenticated_shell.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:homecare_app/features/auth/presentation/screens/authentication_gate.dart';
import 'package:homecare_app/features/auth/presentation/screens/login_screen.dart';

import '../../../../helpers/mock_auth_bloc.dart';

void main() {
  setUpAll(registerAuthFallbackValues);

  testWidgets('AuthenticationGate shows LoginScreen for Unauthenticated state',
      (tester) async {
    final mockBloc = MockAuthBloc();
    final state = Unauthenticated();

    when(() => mockBloc.state).thenReturn(state);
    whenListen(mockBloc, Stream<AuthState>.value(state), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: mockBloc,
          child: const AuthenticationGate(),
        ),
      ),
    );

    expect(find.byType(LoginScreen), findsOneWidget);
    addTearDown(mockBloc.close);
  });

  testWidgets('AuthenticationGate shows AuthenticatedShell for Authenticated state',
      (tester) async {
    final mockBloc = MockAuthBloc();
    final state = Authenticated();

    when(() => mockBloc.state).thenReturn(state);
    whenListen(mockBloc, Stream<AuthState>.value(state), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: mockBloc,
          child: const AuthenticationGate(),
        ),
      ),
    );

    expect(find.byType(AuthenticatedShell), findsOneWidget);
    addTearDown(mockBloc.close);
  });
}
