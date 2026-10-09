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

  // Opens Profile on top of a stand-in home screen so that logging out has a
  // stack to clear, and records what the secure-storage plugin is asked to do.
  Future<void> pumpScreen(WidgetTester tester) async {
    installFakeApi({'GET /requirements/mine': (_) => []});
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

  testWidgets('shows the account details in a single GlowCard', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Meera Nair'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);
    expect(find.text('meera@example.com'), findsOneWidget);
    expect(find.text('M'), findsOneWidget,
        reason: 'the avatar shows the initial');
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
    expect(find.text('login stub'), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.text('open'), findsNothing,
        reason: 'the whole stack was cleared');
  });

  testWidgets('Edit profile saves a new name and the profile shows it',
      (tester) async {
    final original = customerProfile.value;
    addTearDown(() => customerProfile.value = original);
    await pumpScreen(tester);

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Meera Nair'), 'New Name');
    await tester.enterText(
        find.widgetWithText(TextField, 'meera@example.com'), '');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('New Name'), findsOneWidget);
    expect(find.text('meera@example.com'), findsNothing);
    expect(find.text('Profile updated.'), findsOneWidget);
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
}
