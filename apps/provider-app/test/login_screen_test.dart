import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_provider/features/auth/login_screen.dart';
import 'package:onehub_provider/features/auth/signup_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.dark(), home: const LoginScreen()),
    );
  }

  testWidgets('is wrapped in PageGlow with a single GlowCard form',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('OneHub for Providers'), findsOneWidget);
    expect(find.widgetWithText(PrimaryCta, 'Login'), findsOneWidget);
  });

  testWidgets('the password field is hidden until the toggle is tapped',
      (tester) async {
    await pumpScreen(tester);

    TextField password() => tester
        .widget<TextField>(find.widgetWithText(TextField, 'Your password'));
    expect(password().obscureText, isTrue);

    await tester.tap(find.byIcon(OneHubIcons.hide));
    await tester.pump();

    expect(password().obscureText, isFalse);
  });

  testWidgets('Sign up opens the signup screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Sign up'));
    // SignupScreen shows a looping spinner while categories load, so
    // pumpAndSettle would never converge — advance past the route transition.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SignupScreen), findsOneWidget);
  });

  testWidgets('Forgot Password opens the reset password screen',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
  });
}
