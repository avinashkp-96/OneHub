import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/auth/login_screen.dart';
import 'package:onehub_customer/features/auth/signup_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        routes: {
          '/dashboard': (_) => const Scaffold(body: Text('dashboard stub'))
        },
        home: const LoginScreen(),
      ),
    );
  }

  Future<void> fillAndLogin(WidgetTester tester) async {
    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number or email'),
        ' 9876543210 ');
    await tester.enterText(
        find.widgetWithText(TextField, 'Your password'), 'secret1');
    await tester.tap(find.widgetWithText(PrimaryCta, 'Login'));
    await tester.pumpAndSettle();
  }

  testWidgets('is wrapped in PageGlow with a single GlowCard form',
      (tester) async {
    installFakeApi({});
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('logging in sends trimmed credentials and opens the dashboard',
      (tester) async {
    final fake = installFakeApi({
      'POST /auth/customer/login': (_) => {'accessToken': 'abc'}
    });
    await pumpScreen(tester);
    await fillAndLogin(tester);

    expect(fake.bodies.single,
        {'mobileOrEmail': '9876543210', 'password': 'secret1'});
    expect(find.text('dashboard stub'), findsOneWidget);
  });

  testWidgets('shows the error and stays put when login fails', (tester) async {
    installFakeApi({
      'POST /auth/customer/login': (_) =>
          const FakeError(401, 'Invalid credentials')
    });
    await pumpScreen(tester);
    await fillAndLogin(tester);

    expect(find.textContaining('Could not log in'), findsOneWidget);
    expect(find.text('dashboard stub'), findsNothing);
  });

  testWidgets('the password field is hidden until the toggle is tapped',
      (tester) async {
    installFakeApi({});
    await pumpScreen(tester);

    TextField password() => tester
        .widget<TextField>(find.widgetWithText(TextField, 'Your password'));
    expect(password().obscureText, isTrue);

    await tester.tap(find.byIcon(OneHubIcons.hide));
    await tester.pump();

    expect(password().obscureText, isFalse);
  });

  testWidgets('Sign up opens the signup screen', (tester) async {
    installFakeApi({});
    await pumpScreen(tester);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsOneWidget);
  });

  testWidgets('Forgot Password opens the reset password screen',
      (tester) async {
    installFakeApi({});
    await pumpScreen(tester);

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
  });
}
