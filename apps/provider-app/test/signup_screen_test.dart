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

  // What the ID proof upload and the signup call received.
  String? idProofAuth;
  Map<String, dynamic>? signupBody;

  ApiClient fakeClient({bool failSignup = false}) {
    posted = [];
    return ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST') posted.add(path);
        if (path == '/uploads/id-proof') {
          idProofAuth = request.headers['Authorization'];
          return http.Response(
              jsonEncode({'url': 'upload:id-proofs/abc.jpg'}), 201);
        }
        if (path == '/auth/provider/signup') {
          signupBody = jsonDecode(request.body) as Map<String, dynamic>;
        }
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
        if (path == '/auth/otp/request') {
          return http.Response(
              jsonEncode({'sent': true, 'devOnlyOtp': '482913'}), 201);
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
          home: SignupScreen(
              client: client ?? fakeClient(),
              pickPhoto: (_) async =>
                  PickedPhoto(Uint8List.fromList([1, 2, 3]), 'id.jpg'),
              pickLocation: (_, __) async => const SavedLocation(
                  city: 'Kadavanthra', latitude: 9.9667, longitude: 76.2999))),
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
    // Every problem on the step shows at once, each under its field.
    expect(find.text('Enter your name or business name.'), findsOneWidget);
    expect(find.text('Enter a 10-digit mobile number.'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'John Doe'), 'Asha');
    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number'), '9876543210');
    await next(tester);
    expect(find.text('Enter your name or business name.'), findsNothing);
    expect(find.text('Tap Send OTP to get a code on this number.'),
        findsOneWidget);
  });

  testWidgets('Send OTP unlocks the code field and shows the test code',
      (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('test-code')), findsNothing);

    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number'), '9876543210');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Send OTP'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Test code: 482913', findRichText: true),
        findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '6-digit code'))
            .enabled,
        isTrue);
  });

  testWidgets('rejects an invalid mobile number when sending the OTP',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number'), '123');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Send OTP'));
    await tester.pump();

    final mobile =
        tester.widget<TextField>(find.widgetWithText(TextField, '123'));
    expect(mobile.decoration!.errorText, 'Enter a 10-digit mobile number.');
  });

  testWidgets('step 1 checks the code and the passwords', (tester) async {
    await pumpScreen(tester);
    await completeStepOne(tester);

    await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'), '12');
    await next(tester);
    expect(find.text('Enter the 6-digit code.'), findsOneWidget);
    expect(find.text('STEP 1 OF 3'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'), '123456');
    await tester.enterText(
        find.widgetWithText(TextField, 'Re-enter'), 'different');
    await next(tester);
    expect(find.text('The passwords do not match.'), findsOneWidget);
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
    expect(find.text('Choose your service category.'), findsOneWidget);

    await tester.tap(find.text('Electrician'));
    await tester.pumpAndSettle();
    await next(tester);
    expect(find.text('Choose at least one service you offer.'), findsOneWidget);
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

    expect(find.text('Choose at least one service you offer.'), findsOneWidget);
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
    expect(find.text('Choose where your business is.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('choose-location')));
    await tester.pumpAndSettle();
    expect(find.text('Kadavanthra'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    await tester.tap(find.widgetWithText(PrimaryCta, 'Create Account'));
    await tester.pump();
    expect(find.text('Upload a photo of your ID proof for verification.'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('upload-id-proof')));
    await tester.pumpAndSettle();
    expect(find.text('ADDED'), findsOneWidget);
    expect(posted, contains('/uploads/id-proof'));
    expect(idProofAuth, isNull, reason: 'there is no account to sign in yet');
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
    expect(signupBody!['idProofUrl'], 'upload:id-proofs/abc.jpg');
    expect(signupBody!['latitude'], 9.9667);
    expect(signupBody!['longitude'], 76.2999);
    expect(signupBody!['city'], 'Kadavanthra');
  });

  testWidgets('the Terms link on step 3 opens the Terms & privacy page',
      (tester) async {
    await pumpScreen(tester);
    await completeStepOne(tester);
    await next(tester);
    await completeStepTwo(tester);
    await next(tester);

    expect(find.byKey(const Key('privacy-link')), findsNothing);
    await tester.tap(find.byKey(const Key('terms-link')));
    await tester.pumpAndSettle();

    expect(find.byType(InfoScreen), findsOneWidget);
  });

  testWidgets('shows the server error on step 3 when sign-up fails',
      (tester) async {
    await pumpScreen(tester, client: fakeClient(failSignup: true));
    await completeStepOne(tester);
    await next(tester);
    await completeStepTwo(tester);
    await next(tester);

    await tester.tap(find.byKey(const Key('choose-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('upload-id-proof')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryCta, 'Create Account'));
    await tester.pumpAndSettle();

    // The refusal is about the mobile number, so it goes back to step 1
    // and shows under that field.
    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    final mobile = tester.widget<TextField>(
        find.widgetWithText(TextField, '9876543210'));
    expect(mobile.decoration!.errorText, 'Mobile already registered.');
    expect(find.text('Account Created!'), findsNothing);
  });

  testWidgets('a Send OTP that fails shows a plain message, never a code',
      (tester) async {
    // What the app saw when opened on the Flutter dev server instead of the
    // gateway: a 404 with no reason.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(),
        home: SignupScreen(
            client: ApiClient(
                baseUrl: 'https://example.test',
                httpClient: MockClient(
                    (_) async => http.Response('Not Found', 404))))));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number'), '9876543210');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text(serverTroubleMessage), findsOneWidget);
    expect(find.textContaining('404'), findsNothing);
    expect(find.textContaining('ApiException'), findsNothing);
  });
}
