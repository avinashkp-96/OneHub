import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  test('testCodeFrom reads devOnlyOtp, and nothing without it', () {
    expect(testCodeFrom({'sent': true, 'devOnlyOtp': '482913'}), '482913');
    expect(testCodeFrom({'sent': true}), isNull,
        reason: 'production sends no code');
    expect(testCodeFrom({'devOnlyOtp': ''}), isNull);
  });

  testWidgets('TestCodeHint shows the code, or nothing', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(),
        home: const Scaffold(
            body: Column(children: [TestCodeHint(null), TestCodeHint('482913')]))));
    expect(find.byKey(const Key('test-code')), findsOneWidget);
    expect(find.textContaining('482913', findRichText: true), findsOneWidget);
  });

  testWidgets('reset password shows the test code under the code field',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: ResetPasswordScreen(
          client: ApiClient(
              baseUrl: 'https://example.test',
              httpClient: MockClient((_) async => http.Response(
                  jsonEncode({'sent': true, 'devOnlyOtp': '048213'}), 201)))),
    ));
    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number or email'), '9876543210');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Test code: 048213', findRichText: true),
        findsOneWidget);
  });
}
