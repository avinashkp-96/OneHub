import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/auth/signup_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        routes: {
          '/dashboard': (_) => const Scaffold(body: Text('dashboard stub'))
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => SignupScreen(
                            pickLocation: (_, __) async => const SavedLocation(
                                city: 'Edappally',
                                latitude: 10.0261,
                                longitude: 76.3125)))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fillAddress(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('address-location')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('address-house')), '12B, Palm Grove');
    await tester.enterText(
        find.byKey(const Key('address-street')), 'Changampuzha Nagar');
    await tester.enterText(find.byKey(const Key('address-pincode')), '682024');
  }

  Future<void> fillForm(WidgetTester tester,
      {String confirm = 'secret1', bool terms = true}) async {
    await fillAddress(tester);
    await tester.enterText(find.widgetWithText(TextField, 'John Doe'), 'Meera');
    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number'), '9876543210');
    await tester.enterText(
        find.widgetWithText(TextField, 'Min. 6 chars'), 'secret1');
    await tester.enterText(find.widgetWithText(TextField, 'Re-enter'), confirm);
    if (terms) await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  Future<void> submitForm(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(PrimaryCta, 'Create Account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> enterCode(WidgetTester tester, String code) async {
    final fields = find.byType(TextField);
    for (var i = 0; i < code.length; i++) {
      await tester.enterText(fields.at(i), code[i]);
      await tester.pump();
    }
  }

  FakeApi okApi() => installFakeApi({
        'POST /auth/otp/request': (_) => {'sent': true},
        'POST /auth/customer/signup': (_) => {'ok': true},
      });

  testWidgets('shows the form with a single GlowCard', (tester) async {
    okApi();
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Create Account.'), findsOneWidget);
  });

  testWidgets('validates each field before asking for an OTP', (tester) async {
    final fake = okApi();
    await pumpScreen(tester);

    await submitForm(tester);
    expect(find.text('Enter your full name.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'John Doe'), 'Meera');
    await submitForm(tester);
    expect(find.text('Enter a 10-digit mobile number.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, '10-digit number'), '9876543210');
    await tester.enterText(
        find.widgetWithText(TextField, 'Min. 6 chars'), '123');
    await submitForm(tester);
    expect(
        find.text('Password must be at least 6 characters.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Min. 6 chars'), 'secret1');
    await tester.enterText(
        find.widgetWithText(TextField, 'Re-enter'), 'different');
    await submitForm(tester);
    expect(find.text('The passwords do not match.'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Re-enter'), 'secret1');
    await submitForm(tester);
    expect(find.text('Set the address on the map: use GPS or pick your area.'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('address-location')));
    await tester.pumpAndSettle();
    expect(find.text('Edappally'), findsOneWidget);
    await submitForm(tester);
    expect(find.text('Enter the house or flat number.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('address-house')), '12B');
    await submitForm(tester);
    expect(find.text('Enter the street and area.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('address-street')), 'MG Road');
    await tester.enterText(find.byKey(const Key('address-pincode')), '68202');
    await submitForm(tester);
    expect(find.text('Enter a 6-digit PIN code.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('address-pincode')), '682024');
    await submitForm(tester);
    expect(find.text('Accept the Terms & Conditions to continue.'),
        findsOneWidget);

    expect(fake.calls, isEmpty);
  });

  testWidgets('sends the address with the new account', (tester) async {
    final fake = okApi();
    await pumpScreen(tester);
    await fillForm(tester);
    await tester.enterText(
        find.byKey(const Key('address-landmark')), ' Near the church ');
    await submitForm(tester);
    await tester.pumpAndSettle();
    await enterCode(tester, '123456');
    await tester.tap(find.widgetWithText(PrimaryCta, 'Verify & Create Account'));
    await tester.pumpAndSettle();

    expect(fake.bodies.last['address'], {
      'label': 'Home',
      'house': '12B, Palm Grove',
      'street': 'Changampuzha Nagar',
      'landmark': 'Near the church',
      'pincode': '682024',
      'city': 'Edappally',
      'latitude': 10.0261,
      'longitude': 76.3125,
    });
  });

  testWidgets('the Terms link opens the Terms & privacy page', (tester) async {
    okApi();
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('terms-link')));
    await tester.pumpAndSettle();

    expect(find.byType(InfoScreen), findsOneWidget);
  });

  testWidgets('both password fields toggle visibility independently',
      (tester) async {
    okApi();
    await pumpScreen(tester);

    TextField field(String hint) =>
        tester.widget<TextField>(find.widgetWithText(TextField, hint));
    expect(field('Min. 6 chars').obscureText, isTrue);
    expect(field('Re-enter').obscureText, isTrue);

    await tester.tap(find.byIcon(OneHubIcons.hide).first);
    await tester.pump();
    expect(field('Min. 6 chars').obscureText, isFalse);
    expect(field('Re-enter').obscureText, isTrue);

    await tester.tap(find.byIcon(OneHubIcons.hide));
    await tester.pump();
    expect(field('Re-enter').obscureText, isFalse);
  });

  testWidgets('the Login link goes back to the previous screen',
      (tester) async {
    okApi();
    await pumpScreen(tester);

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.byType(SignupScreen), findsNothing);
  });

  testWidgets('walks through form, OTP and success, then opens the dashboard',
      (tester) async {
    final fake = okApi();
    await pumpScreen(tester);
    await fillForm(tester);
    await submitForm(tester);

    expect(find.text('Phone Verification'), findsOneWidget);
    expect(find.textContaining('+91 9876543210'), findsOneWidget);
    expect(fake.calls, contains('POST /auth/otp/request'));

    await enterCode(tester, '123456');
    await tester
        .tap(find.widgetWithText(PrimaryCta, 'Verify & Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Account Created!'), findsOneWidget);
    expect(fake.bodies.last['otp'], '123456');
    expect(fake.bodies.last['fullName'], 'Meera');

    await tester.tap(find.widgetWithText(PrimaryCta, 'Go to Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('dashboard stub'), findsOneWidget);
  });

  testWidgets('includes the optional email when one is entered',
      (tester) async {
    final fake = okApi();
    await pumpScreen(tester);
    await fillForm(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'you@example.com'), 'meera@example.com');
    await submitForm(tester);
    await enterCode(tester, '123456');
    await tester
        .tap(find.widgetWithText(PrimaryCta, 'Verify & Create Account'));
    await tester.pumpAndSettle();

    expect(fake.bodies.last['email'], 'meera@example.com');
  });

  testWidgets('asks for all six digits before verifying', (tester) async {
    final fake = okApi();
    await pumpScreen(tester);
    await fillForm(tester);
    await submitForm(tester);

    await enterCode(tester, '123');
    await tester
        .tap(find.widgetWithText(PrimaryCta, 'Verify & Create Account'));
    await tester.pump();

    expect(find.text('Enter the 6-digit code we sent you.'), findsOneWidget);
    expect(fake.calls.where((c) => c.contains('signup')), isEmpty);
  });

  testWidgets('the back arrow on the OTP step returns to the form',
      (tester) async {
    okApi();
    await pumpScreen(tester);
    await fillForm(tester);
    await submitForm(tester);

    await tester.tap(find.byIcon(OneHubIcons.arrowLeft));
    await tester.pump();

    expect(find.text('Create Account.'), findsOneWidget);
  });

  testWidgets('resend is locked for 30 seconds, then sends another code',
      (tester) async {
    final fake = okApi();
    await pumpScreen(tester);
    await fillForm(tester);
    await submitForm(tester);

    expect(find.text('Resend code in 0:30'), findsOneWidget);
    await tester.tap(find.text('Resend code in 0:30'), warnIfMissed: false);
    expect(fake.calls.where((c) => c == 'POST /auth/otp/request').length, 1);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Resend code in 0:25'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Resend code'), findsOneWidget);

    await tester.tap(find.text('Resend code'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(fake.calls.where((c) => c == 'POST /auth/otp/request').length, 2);
    expect(find.text('Resend code in 0:30'), findsOneWidget);
  });

  testWidgets('shows an error when the OTP cannot be sent', (tester) async {
    installFakeApi(
        {'POST /auth/otp/request': (_) => const FakeError(500, 'SMS down')});
    await pumpScreen(tester);
    await fillForm(tester);
    await submitForm(tester);

    expect(find.text(serverTroubleMessage), findsOneWidget);
    expect(find.text('Phone Verification'), findsNothing);
  });

  testWidgets('shows an error when the code is rejected', (tester) async {
    installFakeApi({
      'POST /auth/otp/request': (_) => {'sent': true},
      'POST /auth/customer/signup': (_) => const FakeError(400, 'Wrong code'),
    });
    await pumpScreen(tester);
    await fillForm(tester);
    await submitForm(tester);
    await enterCode(tester, '123456');
    await tester
        .tap(find.widgetWithText(PrimaryCta, 'Verify & Create Account'));
    await tester.pumpAndSettle();

    // A code problem stays on the code step, under the boxes.
    expect(find.text('Wrong code.'), findsOneWidget);
    expect(find.text('Phone Verification'), findsOneWidget);
    expect(find.text('Account Created!'), findsNothing);
  });

  testWidgets('a number already registered goes back to the form, under the mobile field',
      (tester) async {
    installFakeApi({
      'POST /auth/otp/request': (_) => {'sent': true},
      'POST /auth/customer/signup': (_) =>
          const FakeError(409, 'mobile number already registered'),
    });
    await pumpScreen(tester);
    await fillForm(tester);
    await submitForm(tester);
    await enterCode(tester, '123456');
    await tester
        .tap(find.widgetWithText(PrimaryCta, 'Verify & Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Create Account.'), findsOneWidget);
    final mobile = tester.widget<TextField>(
        find.widgetWithText(TextField, '9876543210'));
    expect(mobile.decoration!.errorText,
        'This mobile number is already registered. Log in instead.');
  });

  testWidgets('shows an error when resending fails', (tester) async {
    var calls = 0;
    installFakeApi({
      'POST /auth/otp/request': (_) =>
          ++calls == 1 ? {'sent': true} : const FakeError(429, 'Slow down'),
    });
    await pumpScreen(tester);
    await fillForm(tester);
    await submitForm(tester);
    await tester.pump(const Duration(seconds: 31));

    await tester.tap(find.text('Resend code'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Slow down.'), findsOneWidget);
  });
}
