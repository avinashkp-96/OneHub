import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/auth/signup_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ApiClient.get reads the stored token; there is no secure-storage plugin
  // in widget tests, so answer its channel with "no token".
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  late List<String> posted;

  ApiClient fakeClient({bool failSignup = false}) {
    posted = [];
    return ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST') posted.add(path);
        if (path == '/categories') {
          return http.Response(
            jsonEncode([
              {'id': 'c1', 'name': 'Electrician'},
              {'id': 'c2', 'name': 'Plumber'},
            ]),
            200,
          );
        }
        if (path == '/categories/c1/sub-services') {
          return http.Response(
            jsonEncode([
              {'id': 's1', 'categoryId': 'c1', 'name': 'Wiring repair'},
              {'id': 's2', 'categoryId': 'c1', 'name': 'Fan installation'},
            ]),
            200,
          );
        }
        if (path == '/auth/provider/signup' && failSignup) {
          return http.Response(
              jsonEncode({'message': 'Mobile already registered'}), 409);
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, {ApiClient? client}) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
          theme: OneHubTheme.dark(),
          home: SignupScreen(client: client ?? fakeClient())),
    );
    await tester.pumpAndSettle();
  }

  Future<void> completeStepOne(WidgetTester tester) async {
    await tester.enterText(
        find.widgetWithText(TextField, 'John Doe'), 'Asha Electricals');
    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number'), '9876543210');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Send OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'), '123456');
    await tester.enterText(
        find.widgetWithText(TextField, 'Min. 6 chars'), 'secret1');
    await tester.enterText(
        find.widgetWithText(TextField, 'Re-enter'), 'secret1');
  }

  Future<void> completeStepTwo(WidgetTester tester) async {
    await tester.tap(find.text('Electrician'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wiring repair'));
    await tester.pump();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(PrimaryCta, 'Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('step 1 shows basic details with an always-visible OTP field',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Create Provider Account'), findsOneWidget);
    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('OTP *'), findsOneWidget);

    TextField otp() => tester.widget<TextField>(
        find.widgetWithText(TextField, 'Tap Send OTP first'));
    expect(otp().enabled, isFalse);

    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number'), '9876543210');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Send OTP'));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '6-digit code'))
            .enabled,
        isTrue);
    expect(posted, contains('/auth/otp/request'));
  });

  testWidgets('step 1 validates before continuing', (tester) async {
    await pumpScreen(tester);

    await next(tester);
    expect(find.text('Enter your name or business name.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'John Doe'), 'Asha');
    await next(tester);
    expect(find.text('Enter a valid 10-digit mobile number.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number'), '9876543210');
    await next(tester);
    expect(find.text('Tap Send OTP to verify your mobile number.'),
        findsOneWidget);
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

  testWidgets('step 1 checks the code and the passwords', (tester) async {
    await pumpScreen(tester);
    await completeStepOne(tester);

    await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'), '12');
    await next(tester);
    expect(find.text('Enter the 6-digit code.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'), '123456');
    await tester.enterText(
        find.widgetWithText(TextField, 'Re-enter'), 'different');
    await next(tester);
    expect(find.text('Password and confirmation must match.'), findsOneWidget);
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

  testWidgets(
      'step 2 shows categories as a grid and reveals services after picking one',
      (tester) async {
    await pumpScreen(tester);
    await completeStepOne(tester);
    await next(tester);

    expect(find.text('What do you offer?'), findsOneWidget);
    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    expect(find.byType(GlowCard), findsNothing);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Electrician'), findsOneWidget);
    expect(find.text('Plumber'), findsOneWidget);
    expect(find.text('Wiring repair'), findsNothing);

    await tester.tap(find.text('Electrician'));
    await tester.pumpAndSettle();

    expect(find.text('Wiring repair'), findsOneWidget);
    expect(find.text('Fan installation'), findsOneWidget);
    expect(find.byType(GridView), findsNWidgets(2));
  });

  testWidgets('step 2 requires a category and at least one service',
      (tester) async {
    await pumpScreen(tester);
    await completeStepOne(tester);
    await next(tester);

    await next(tester);
    expect(find.text('Select a service category and at least one service.'),
        findsOneWidget);

    await tester.tap(find.text('Electrician'));
    await tester.pumpAndSettle();
    await next(tester);
    expect(find.text('Select a service category and at least one service.'),
        findsOneWidget);
  });

  testWidgets('switching category clears the selected services',
      (tester) async {
    await pumpScreen(tester);
    await completeStepOne(tester);
    await next(tester);
    await completeStepTwo(tester);

    await tester.tap(find.text('Plumber'));
    await tester.pumpAndSettle();
    await next(tester);

    expect(find.text('Select a service category and at least one service.'),
        findsOneWidget);
  });

  testWidgets('back returns to the previous step and keeps what was typed',
      (tester) async {
    await pumpScreen(tester);
    await completeStepOne(tester);
    await next(tester);
    expect(find.text('What do you offer?'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Create Provider Account'), findsOneWidget);
    expect(find.text('Asha Electricals'), findsOneWidget);
  });

  testWidgets(
      'step 3 needs an ID proof and accepted terms, then creates the account',
      (tester) async {
    await pumpScreen(tester);
    await completeStepOne(tester);
    await next(tester);
    await completeStepTwo(tester);
    await next(tester);

    expect(find.text('Business details'), findsOneWidget);
    expect(find.text('STEP 3 OF 3'), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);

    await tester.tap(find.widgetWithText(PrimaryCta, 'Create Account'));
    await tester.pump();
    expect(find.text('ID proof is required for verification.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Document link'),
        'https://example.test/id.pdf');
    await tester.tap(find.widgetWithText(PrimaryCta, 'Create Account'));
    await tester.pump();
    expect(find.text('Accept the Terms & Conditions to continue.'),
        findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryCta, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Account Created!'), findsOneWidget);
    expect(posted, contains('/auth/provider/signup'));
  });

  testWidgets('shows the server error on step 3 when sign-up fails',
      (tester) async {
    await pumpScreen(tester, client: fakeClient(failSignup: true));
    await completeStepOne(tester);
    await next(tester);
    await completeStepTwo(tester);
    await next(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Document link'),
        'https://example.test/id.pdf');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryCta, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mobile already registered'), findsOneWidget);
    expect(find.text('Account Created!'), findsNothing);
  });
}
