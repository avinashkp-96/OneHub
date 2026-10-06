import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_provider/features/auth/signup_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.dark(), home: const SignupScreen()),
    );
    await tester.pump();
  }

  testWidgets('shows the heading and form immediately, with categories loading',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Create Provider Account'), findsOneWidget);
    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.textContaining('FULL NAME / BUSINESS NAME'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('requires a verified mobile number before creating an account',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(PrimaryCta, 'Create Account'));
    await tester.pump();

    expect(find.text('Verify your mobile number first.'), findsOneWidget);
  });

  testWidgets('rejects an invalid mobile number when sending the OTP',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number'), '123');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Send OTP'));
    await tester.pump();

    expect(find.text('Enter a valid 10-digit mobile number.'), findsOneWidget);
  });

  testWidgets('both password fields toggle visibility independently',
      (tester) async {
    await pumpScreen(tester);

    TextField field(String hint) =>
        tester.widget<TextField>(find.widgetWithText(TextField, hint));
    expect(field('Min. 6 chars').obscureText, isTrue);
    expect(field('Re-enter').obscureText, isTrue);

    await tester.tap(find.byIcon(OneHubIcons.hide).first);
    await tester.pump();

    expect(field('Min. 6 chars').obscureText, isFalse);
    expect(field('Re-enter').obscureText, isTrue);
  });

  testWidgets('the terms checkbox toggles', (tester) async {
    await pumpScreen(tester);

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
