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

  // find.text('Reset Password') is ambiguous with the AppBar title of the
  // same text. PrimaryCta no longer wraps a FilledButton (it's a custom
  // gradient InkWell), so find the button by its PrimaryCta ancestor instead.
  Finder resetPasswordCta() => find.ancestor(of: find.text('Reset Password'), matching: find.byType(PrimaryCta));

  testWidgets('walks through request-OTP, reset, and the success step', (tester) async {
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
    await tester.enterText(find.widgetWithText(TextField, 'Mobile Number or Email'), '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('OTP'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'OTP'), '1234');
    await tester.enterText(find.widgetWithText(TextField, 'New Password'), 'newpass1');
    await tester.enterText(find.widgetWithText(TextField, 'Confirm New Password'), 'newpass1');
    await tester.tap(resetPasswordCta());
    await tester.pumpAndSettle();

    expect(find.textContaining('Password reset.'), findsOneWidget);
  });

  testWidgets('shows an error instead of advancing when passwords do not match', (tester) async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async => http.Response(jsonEncode({'sent': true}), 200)),
    );

    await tester.pumpWidget(wrap(client));
    await tester.enterText(find.widgetWithText(TextField, 'Mobile Number or Email'), '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'New Password'), 'newpass1');
    await tester.enterText(find.widgetWithText(TextField, 'Confirm New Password'), 'different');
    await tester.tap(resetPasswordCta());
    await tester.pumpAndSettle();

    expect(find.text('New password and confirmation must match.'), findsOneWidget);
  });
}
