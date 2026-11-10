import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/profile/profile_screen.dart';
import 'package:onehub_customer/features/requirements/my_requests_screen.dart';
import 'package:onehub_customer/features/profile/profile_state.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  late List<String> storageCalls;
  late FakeApi fake;

  Map<String, dynamic> meJson({String? email = 'meera@example.com'}) => {
        'id': 'u1',
        'role': 'CUSTOMER',
        'fullName': 'Meera Nair',
        'mobile': '9000000001',
        'email': email,
      };

  // Opens Profile on top of a stand-in home screen so that logging out has a
  // stack to clear, and records what the secure-storage plugin is asked to do.
  Future<void> pumpScreen(WidgetTester tester,
      {Map<String, Object? Function(dynamic)> routes = const {}}) async {
    customerProfile.value = null;
    addTearDown(() => customerProfile.value = null);
    fake = installFakeApi({
      'GET /requirements/mine': (_) => [],
      'GET /users/me': (_) => meJson(),
      ...routes,
    });
    storageCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        storageCalls.add('${call.method} ${(call.arguments as Map)['key']}');
        return null;
      },
    );
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        routes: {'/login': (_) => const Scaffold(body: Text('login stub'))},
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
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

  testWidgets('shows the account from GET /users/me in a single GlowCard',
      (tester) async {
    await pumpScreen(tester);

    expect(fake.calls, contains('GET /users/me'));
    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Meera Nair'), findsOneWidget);
    expect(find.text('+91 90000 00001'), findsOneWidget);
    expect(find.text('meera@example.com'), findsOneWidget);
    expect(find.text('M'), findsOneWidget,
        reason: 'the avatar shows the initial');
  });

  testWidgets('an account with no email shows no email row', (tester) async {
    await pumpScreen(tester,
        routes: {'GET /users/me': (_) => meJson(email: null)});

    expect(find.text('Meera Nair'), findsOneWidget);
    expect(find.byIcon(OneHubIcons.email), findsNothing);
  });

  testWidgets('a failed load says so, and pulling down retries',
      (tester) async {
    var fail = true;
    await pumpScreen(tester, routes: {
      'GET /users/me': (_) => fail ? const FakeError(500) : meJson(),
    });

    expect(find.text('Could not load your profile. Pull down to retry.'),
        findsOneWidget);

    fail = false;
    await tester.drag(find.byType(ListView), const Offset(0, 1500));
    await tester.pumpAndSettle();

    expect(find.text('Meera Nair'), findsOneWidget);
  });

  testWidgets('My requests opens the requests screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('My requests'));
    await tester.pumpAndSettle();

    expect(find.byType(MyRequestsScreen), findsOneWidget);
  });

  testWidgets('the back button returns to the previous screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('Log out asks for confirmation first', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(storageCalls.where((c) => c.startsWith('delete')), isEmpty);
  });

  testWidgets('cancelling leaves you signed in on the profile screen',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Log out?'), findsNothing);
    expect(storageCalls.where((c) => c.startsWith('delete')), isEmpty);
  });

  testWidgets(
      'confirming clears the token and lands on login with nothing to go back to',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(storageCalls, contains('delete access_token'));
    expect(customerProfile.value, isNull,
        reason: 'the next account must not see this one\'s details');
    expect(find.text('login stub'), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.text('open'), findsNothing,
        reason: 'the whole stack was cleared');
  });

  testWidgets('Edit profile saves through PATCH /users/me and shows the result',
      (tester) async {
    await pumpScreen(tester, routes: {
      'PATCH /users/me': (_) => {
            ...meJson(email: null),
            'fullName': 'New Name',
          },
    });

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('Saved on this device only for now.'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextField, 'Meera Nair'), 'New Name');
    await tester.enterText(
        find.widgetWithText(TextField, 'meera@example.com'), '');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('PATCH /users/me'));
    expect(fake.bodies.last, {'fullName': 'New Name', 'email': null},
        reason: 'an emptied email is sent as null, which clears it');
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('New Name'), findsOneWidget);
    expect(find.text('meera@example.com'), findsNothing);
    expect(find.text('Profile updated.'), findsOneWidget);
  });

  testWidgets('a refused save keeps Edit profile open with the API message',
      (tester) async {
    await pumpScreen(tester, routes: {
      'PATCH /users/me': (_) => const FakeError(409, 'email already in use'),
    });

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'meera@example.com'),
        'taken@example.com');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('Could not save your profile: email already in use'),
        findsOneWidget);
    expect(customerProfile.value?.email, 'meera@example.com');
  });

  testWidgets('Settings opens with this app\'s toggles and remembers a change',
      (tester) async {
    final toggle = customerSettingsToggles.first.value;
    final before = toggle.value;
    addTearDown(() => toggle.value = before);
    await pumpScreen(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('OneHub'), findsOneWidget);

    await tester.tap(find.text(customerSettingsToggles.first.title));
    await tester.pump();
    expect(toggle.value, !before);
  });

  testWidgets('Help & support opens the FAQ and contact details',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Help & support'));
    await tester.pumpAndSettle();

    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.text('CONTACT US'), findsOneWidget);
    expect(find.text('Frequently asked'), findsOneWidget);
  });

  testWidgets('Terms & privacy opens the text with the draft notice',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Terms & privacy'));
    await tester.pumpAndSettle();

    expect(find.byType(InfoScreen), findsOneWidget);
    expect(find.text(legalPlaceholderNotice), findsOneWidget);
    expect(find.text('Using OneHub'), findsOneWidget);
  });
}
