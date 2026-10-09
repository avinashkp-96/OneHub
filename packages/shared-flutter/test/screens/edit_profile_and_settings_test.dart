import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  const initial = ProfileDetails(
      name: 'Meera Nair', phone: '+91 98765 43210', email: 'meera@example.com');

  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('EditProfileScreen', () {
    late List<List<String>> saved;

    Future<void> pumpEdit(WidgetTester tester) async {
      saved = [];
      tallView(tester);
      await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                        initial: initial,
                        onSave: (n, e) => saved.add([n, e]),
                      ))),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the current values with the phone number locked',
        (tester) async {
      await pumpEdit(tester);

      expect(find.byType(PageGlow), findsOneWidget);
      expect(find.byType(GlowCard), findsOneWidget);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Meera Nair'), findsOneWidget);
      expect(find.text('meera@example.com'), findsOneWidget);
      final phone = tester
          .widget<TextField>(find.widgetWithText(TextField, '+91 98765 43210'));
      expect(phone.enabled, isFalse);
    });

    testWidgets('saves trimmed values, goes back and confirms', (tester) async {
      await pumpEdit(tester);

      await tester.enterText(
          find.widgetWithText(TextField, 'Meera Nair'), '  Meera N  ');
      await tester.enterText(
          find.widgetWithText(TextField, 'meera@example.com'), '');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(saved, [
        ['Meera N', '']
      ]);
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('Profile updated.'), findsOneWidget);
    });

    testWidgets('rejects an empty name', (tester) async {
      await pumpEdit(tester);

      await tester.enterText(
          find.widgetWithText(TextField, 'Meera Nair'), '   ');
      await tester.tap(find.text('Save changes'));
      await tester.pump();

      expect(find.text('Enter a name.'), findsOneWidget);
      expect(saved, isEmpty);
    });

    testWidgets('rejects an invalid email', (tester) async {
      await pumpEdit(tester);

      await tester.enterText(
          find.widgetWithText(TextField, 'meera@example.com'), 'nope');
      await tester.tap(find.text('Save changes'));
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(saved, isEmpty);
    });

    test('copyWith keeps the phone number', () {
      final c = initial.copyWith(name: 'A', email: 'a@b.co');
      expect(c.phone, initial.phone);
      expect(c.name, 'A');
      expect(c.email, 'a@b.co');
    });
  });

  group('SettingsScreen', () {
    testWidgets('lists the toggles and flips them', (tester) async {
      tallView(tester);
      final push = ValueNotifier(true);
      final promo = ValueNotifier(false);
      await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(),
        home: SettingsScreen(
          appName: 'OneHub Test',
          toggles: [
            SettingsToggle(
                title: 'Push alerts', subtitle: 'Request updates', value: push),
            SettingsToggle(
                title: 'Offers', subtitle: 'Promotions', value: promo),
          ],
        ),
      ));

      expect(find.byType(PageGlow), findsOneWidget);
      expect(find.byType(GlowCard), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Push alerts'), findsOneWidget);
      expect(find.text('OneHub Test'), findsOneWidget);
      expect(find.text('Version 1.0.0'), findsOneWidget);

      await tester.tap(find.text('Push alerts'));
      await tester.tap(find.text('Offers'));
      await tester.pump();

      expect(push.value, isFalse);
      expect(promo.value, isTrue);
    });
  });
}
