import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  group('userMessage', () {
    test('never shows a status code or class name', () {
      final m = userMessage(ApiException(404, 'request failed'));
      expect(m, serverTroubleMessage);
      expect(m, isNot(contains('404')));
      expect(m, isNot(contains('ApiException')));
    });

    test('a server fault or an empty reason reads as our problem', () {
      expect(userMessage(ApiException(500, 'Internal server error')),
          serverTroubleMessage);
      expect(userMessage(ApiException(400, '')), serverTroubleMessage);
      expect(userMessage(ApiException(400, 'upload failed')), serverTroubleMessage);
    });

    test('known API reasons are reworded, others become sentences', () {
      expect(userMessage(ApiException(409, 'mobile number already registered')),
          'This mobile number is already registered. Log in instead.');
      expect(userMessage(ApiException(400, 'invalid or expired OTP')),
          'That code is wrong or has expired. Request a new one.');
      expect(userMessage(ApiException(400, 'this request has expired')),
          'This request has expired.');
      expect(userMessage(ApiException(400, 'Already a sentence!')),
          'Already a sentence!');
    });

    test('no connection, a plain string and anything else', () {
      expect(userMessage(http.ClientException('Failed to fetch')), offlineMessage);
      expect(userMessage(TimeoutException('slow')), offlineMessage);
      expect(userMessage('email already in use'),
          'Another account already uses this email.');
      expect(userMessage('keep at least one address'), 'Keep at least one address.');
      expect(userMessage(Exception('x')), 'Something went wrong. Please try again.');
    });
  });

  group('errorField', () {
    const fields = {
      'otp': ['otp', 'code'],
      'mobile': ['mobile'],
    };

    test('finds the field an API reason is about', () {
      expect(errorField(ApiException(400, 'invalid or expired OTP'), fields), 'otp');
      expect(errorField(ApiException(409, 'mobile number already registered'), fields),
          'mobile');
      expect(errorField('mobile must be exactly 10 digits', fields), 'mobile');
    });

    test('a server fault, another reason or no connection is no field', () {
      expect(errorField(ApiException(500, 'mobile db down'), fields), isNull);
      expect(errorField(ApiException(400, 'something else'), fields), isNull);
      expect(errorField(http.ClientException('offline'), fields), isNull);
    });
  });

  group('ApiClient reasons', () {
    ApiClient answering(int status, Object body) => ApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient(
              (_) async => http.Response(jsonEncode(body), status)),
        );

    test('a validation list gives its first reason', () async {
      final api = answering(400, {
        'message': ['mobile must be exactly 10 digits', 'otp must be a string']
      });
      await expectLater(
          api.post('/auth/otp/request', {}),
          throwsA(isA<ApiException>().having(
              (e) => e.message, 'message', 'mobile must be exactly 10 digits')));
    });

    test('a body with no reason, on GET too, and toString is the reason only',
        () async {
      final api = ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((_) async => http.Response('<html>404</html>', 404)),
      );
      try {
        await api.get('/nowhere');
        fail('should throw');
      } on ApiException catch (e) {
        expect(e.message, 'request failed');
        expect('$e', 'request failed');
      }
    });

    test('delete sends a signed-in DELETE', () async {
      final seen = <String>[];
      final api = ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async {
          seen.add('${r.method} ${r.url.path}');
          return http.Response(jsonEncode({'deleted': 'a1'}), 200);
        }),
      );
      expect(await api.delete('/users/me/addresses/a1'), {'deleted': 'a1'});
      expect(seen, ['DELETE /users/me/addresses/a1']);
    });
  });

  testWidgets('FieldError shows its text in the danger colour, or nothing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(),
        home: const Scaffold(
            body: Column(children: [FieldError(null), FieldError('Pick one.')]))));
    expect(find.text('Pick one.'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Pick one.')).style!.color,
        OneHubColors.danger);

    // Text-field errors wrap instead of being cut off beside a button.
    expect(OneHubTheme.dark().inputDecorationTheme.errorMaxLines, 3);
    expect(OneHubTheme.light().inputDecorationTheme.errorMaxLines, 3);
  });

  group('ResetPasswordScreen errors', () {
    Future<void> pump(WidgetTester tester, http.Response Function(http.Request) answer) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(),
        home: ResetPasswordScreen(
            client: ApiClient(
                baseUrl: 'https://example.test',
                httpClient: MockClient((r) async => answer(r)))),
      ));
    }

    TextField field(WidgetTester tester, String hint) =>
        tester.widget<TextField>(find.widgetWithText(TextField, hint));

    testWidgets('an empty contact and an unknown account show under the field',
        (tester) async {
      await pump(tester, (_) => http.Response(
          jsonEncode({'message': 'no account for that mobile/email'}), 400));

      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();
      expect(field(tester, '10-digit number or email').decoration!.errorText,
          'Enter your registered mobile number or email.');

      await tester.enterText(
          find.widgetWithText(TextField, '10-digit number or email'), 'x@y.co');
      await tester.pump();
      expect(field(tester, '10-digit number or email').decoration!.errorText, isNull,
          reason: 'typing clears it');
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();
      expect(find.text('No account uses that mobile number or email.'), findsOneWidget);
    });

    testWidgets('a wrong code shows under the code, no connection above the form',
        (tester) async {
      var step = 0;
      await pump(tester, (r) {
        step++;
        if (step == 1) return http.Response(jsonEncode({'sent': true}), 200);
        if (step == 2) {
          return http.Response(jsonEncode({'message': 'invalid or expired OTP'}), 400);
        }
        throw http.ClientException('offline');
      });
      await tester.enterText(
          find.widgetWithText(TextField, '10-digit number or email'), '9876543210');
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '123456');
      await tester.enterText(find.widgetWithText(TextField, 'Min. 6 chars'), 'secret1');
      await tester.enterText(find.widgetWithText(TextField, 'Re-enter'), 'secret1');
      await tester.tap(find.widgetWithText(PrimaryCta, 'Reset Password'));
      await tester.pumpAndSettle();
      expect(field(tester, '6-digit code').decoration!.errorText,
          'That code is wrong or has expired. Request a new one.');

      await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '654321');
      await tester.tap(find.widgetWithText(PrimaryCta, 'Reset Password'));
      await tester.pumpAndSettle();
      expect(find.text(offlineMessage), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Min. 6 chars'), '123');
      await tester.tap(find.widgetWithText(PrimaryCta, 'Reset Password'));
      await tester.pumpAndSettle();
      expect(field(tester, 'Min. 6 chars').decoration!.errorText,
          'Password must be at least 6 characters.');
    });
  });

  testWidgets('EditProfileScreen shows name, email and API problems at their fields',
      (tester) async {
    Object? failWith;
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: EditProfileScreen(
        initial: const ProfileDetails(name: 'Meera', phone: '+91 90000 00001', email: ''),
        onSave: (_, __) async {
          final error = failWith;
          if (error != null) throw error;
        },
      ),
    ));
    final fields = find.byType(TextField);

    await tester.enterText(fields.at(0), ' ');
    await tester.enterText(fields.at(2), 'not-an-email');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);

    await tester.enterText(fields.at(0), 'Meera');
    await tester.enterText(fields.at(2), 'taken@example.test');
    failWith = ApiException(409, 'email already in use');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(2)).decoration!.errorText,
        'Another account already uses this email.');
  });
}
