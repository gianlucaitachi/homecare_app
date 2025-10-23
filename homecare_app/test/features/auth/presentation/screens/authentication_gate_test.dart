import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homecare_app/features/app_shell/presentation/authenticated_shell.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart'
    show AuthBloc, AuthState, Authenticated, Unauthenticated, AuthLoading;
import 'package:homecare_app/features/auth/presentation/screens/authentication_gate.dart';
import 'package:homecare_app/features/auth/presentation/screens/login_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mock_auth_bloc.dart';

void main() {
  late MockAuthBloc mockAuthBloc;

  setUpAll(() {
    registerAuthFallbackValues();
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
  });

  tearDown(() {
    mockAuthBloc.close();
  });

  Widget buildGate() {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: const AuthenticationGate(),
      ),
    );
  }

  testWidgets('renders AuthenticatedShell when state is Authenticated',
      (tester) async {
    const state = Authenticated();
    when(() => mockAuthBloc.state).thenReturn(state);
    whenListen(mockAuthBloc, Stream<AuthState>.value(state), initialState: state);

    await tester.pumpWidget(buildGate());
    await tester.pump();

    expect(find.byType(AuthenticatedShell), findsOneWidget);
  });

  testWidgets('renders LoginScreen when state is Unauthenticated', (tester) async {
    const state = Unauthenticated();
    when(() => mockAuthBloc.state).thenReturn(state);
    whenListen(mockAuthBloc, Stream<AuthState>.value(state), initialState: state);

    await tester.pumpWidget(buildGate());
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('shows loading indicator for other states', (tester) async {
    final state = AuthLoading();
    when(() => mockAuthBloc.state).thenReturn(state);
    whenListen(mockAuthBloc, Stream<AuthState>.value(state), initialState: state);

    await tester.pumpWidget(buildGate());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
