import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  Widget wrap(ApiClient client) => MaterialApp(
        theme: OneHubTheme.light(),
        home: ResetPasswordScreen(client: client),
      );

  // PrimaryCta no longer wraps a FilledButton (it's a custom gradient
  // InkWell), so find the button by its PrimaryCta ancestor instead.
  Finder resetPasswordCta() =>
      find.widgetWithText(PrimaryCta, 'Reset Password');

  testWidgets('walks through request-OTP, reset, and the success step',
      (tester) async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/otp/request') {
          return http.Response(jsonEncode({'sent': true}), 200);
        }
        if (request.url.path == '/auth/password/reset') {
          return http.Response(jsonEncode({'reset': true}), 200);
        }
        return http.Response(jsonEncode({'message': 'not found'}), 404);
      }),
    );

    await tester.pumpWidget(wrap(client));

    expect(find.text('Send OTP'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number or email'),
        '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('OTP'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'), '1234');
    await tester.enterText(
        find.widgetWithText(TextField, 'Min. 6 chars'), 'newpass1');
    await tester.enterText(
        find.widgetWithText(TextField, 'Re-enter'), 'newpass1');
    await tester.tap(resetPasswordCta());
    await tester.pumpAndSettle();

    expect(find.text('Password Reset!'), findsOneWidget);
    expect(find.text('Log in with your new password.'), findsOneWidget);
  });

  testWidgets('shows an error instead of advancing when passwords do not match',
      (tester) async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
          (request) async => http.Response(jsonEncode({'sent': true}), 200)),
    );

    await tester.pumpWidget(wrap(client));
    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number or email'),
        '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Min. 6 chars'), 'newpass1');
    await tester.enterText(
        find.widgetWithText(TextField, 'Re-enter'), 'different');
    await tester.tap(resetPasswordCta());
    await tester.pumpAndSettle();

    expect(
        find.text('New password and confirmation must match.'), findsOneWidget);
  });

  testWidgets(
      'the whole screen is wrapped in PageGlow, with a GlowCard per step',
      (tester) async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
          (request) async => http.Response(jsonEncode({'sent': true}), 200)),
    );

    await tester.pumpWidget(wrap(client));

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
  });
}
