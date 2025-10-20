// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homecare_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:homecare_app/features/auth/presentation/screens/login_screen.dart';

import 'helpers/mock_auth_bloc.dart';

void main() {
  setUpAll(registerAuthFallbackValues);

  testWidgets('Login screen UI test', (WidgetTester tester) async {
    final mockBloc = MockAuthBloc();
    final state = Unauthenticated();

    when(() => mockBloc.state).thenReturn(state);
    whenListen(mockBloc, Stream<AuthState>.value(state), initialState: state);

    // Build the login screen within a BlocProvider context.
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: mockBloc,
          child: const LoginScreen(),
        ),
      ),
    );

    // Verify that the Login screen is displayed
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget);

    addTearDown(mockBloc.close);
  });
}
