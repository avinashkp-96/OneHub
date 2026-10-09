import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/profile/profile_screen.dart';
import 'package:onehub_provider/features/requirements/active_jobs_screen.dart';
import 'package:onehub_provider/features/profile/profile_state.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> storageCalls;

  // Opens Profile on top of a stand-in home screen so that logging out has a
  // stack to clear, and records what the secure-storage plugin is asked to do.
  Future<void> pumpScreen(WidgetTester tester) async {
    storageCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        storageCalls.add('${call.method} ${(call.arguments as Map)['key']}');
        return null;
      },
    );
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient:
          MockClient((request) async => http.Response(jsonEncode([]), 200)),
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
                  MaterialPageRoute(
                      builder: (_) => ProfileScreen(client: client)),
                ),
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
    expect(find.text('Asha Electricals'), findsOneWidget);
    expect(find.text('+91 98765 12345'), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('A'), findsOneWidget,
        reason: 'the avatar shows the initial');
  });

  testWidgets('lists the business details', (tester) async {
    await pumpScreen(tester);

    expect(find.text('SERVICE CATEGORY'), findsOneWidget);
    expect(find.text('Electrician'), findsOneWidget);
    expect(find.text('COVERAGE'), findsOneWidget);
    expect(find.text('5 km radius'), findsOneWidget);
    expect(find.text('EXPERIENCE'), findsOneWidget);
    expect(find.text('8 years'), findsOneWidget);
  });

  testWidgets('Active jobs opens the jobs screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Active jobs'));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveJobsScreen), findsOneWidget);
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

  testWidgets('cancelling leaves you on the profile screen', (tester) async {
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
    final original = providerProfile.value;
    addTearDown(() => providerProfile.value = original);
    await pumpScreen(tester);

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Asha Electricals'), 'New Name');
    await tester.enterText(
        find.widgetWithText(TextField, 'asha@example.com'), '');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('New Name'), findsOneWidget);
    expect(find.text('asha@example.com'), findsNothing);
    expect(find.text('Profile updated.'), findsOneWidget);
  });

  testWidgets('Settings opens with this app\'s toggles and remembers a change',
      (tester) async {
    final toggle = providerSettingsToggles.first.value;
    final before = toggle.value;
    addTearDown(() => toggle.value = before);
    await pumpScreen(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('OneHub Provider'), findsOneWidget);

    await tester.tap(find.text(providerSettingsToggles.first.title));
    await tester.pump();
    expect(toggle.value, !before);
  });
}
