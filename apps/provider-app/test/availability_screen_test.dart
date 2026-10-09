import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_provider/features/availability/availability_screen.dart';
import 'package:onehub_provider/features/profile/profile_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  const initial = Availability(
    radiusKm: 5,
    days: {0, 1, 2, 3, 4, 5},
    start: TimeOfDay(hour: 9, minute: 0),
    end: TimeOfDay(hour: 18, minute: 0),
  );

  setUp(() => providerAvailability.value = initial);

  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // Opens the screen on top of a stand-in so Save (which pops) has somewhere
  // to go and its snackbar has a Scaffold to show on.
  Future<void> pumpScreen(WidgetTester tester) async {
    tallView(tester);
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AvailabilityScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the current hours, days and service area', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Availability'), findsOneWidget);
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('6:00 PM'), findsOneWidget);
    for (final d in weekdayLabels) {
      expect(find.text(d), findsOneWidget);
    }
    for (final km in coverageOptionsKm) {
      expect(find.text('$km km'), findsOneWidget);
    }
  });

  testWidgets('saving updates the shared availability and shows a message',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Sun')); // add Sunday
    await tester.tap(find.text('Mon')); // remove Monday
    await tester.tap(find.text('15 km'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final a = providerAvailability.value;
    expect(a.radiusKm, 15);
    expect(a.days, {1, 2, 3, 4, 5, 6});
    expect(find.byType(AvailabilityScreen), findsNothing);
    expect(find.text('Availability saved.'), findsOneWidget);
  });

  testWidgets('requires at least one working day', (tester) async {
    await pumpScreen(tester);

    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']) {
      await tester.tap(find.text(d));
    }
    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(find.text('Pick at least one working day.'), findsOneWidget);
    expect(find.byType(AvailabilityScreen), findsOneWidget);
    expect(providerAvailability.value.days, initial.days);
  });

  testWidgets('rejects a closing time that is not after opening',
      (tester) async {
    providerAvailability.value =
        initial.copyWith(end: const TimeOfDay(hour: 8, minute: 0));
    await pumpScreen(tester);

    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(
        find.text('Closing time must be after opening time.'), findsOneWidget);
    expect(find.byType(AvailabilityScreen), findsOneWidget);
  });

  testWidgets('picking a time updates the button', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('9:00 AM'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.text('9:00 AM'), findsOneWidget);
  });

  testWidgets('cancelling the time picker changes nothing', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('9:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('9:00 AM'), findsOneWidget);
  });

  testWidgets('the profile links here and reflects the saved radius',
      (tester) async {
    tallView(tester);
    await tester.pumpWidget(
        MaterialApp(theme: OneHubTheme.dark(), home: const ProfileScreen()));
    expect(find.text('5 km radius'), findsOneWidget);

    await tester.tap(find.text('Availability'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 km'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(AvailabilityScreen), findsNothing);
    expect(find.text('10 km radius'), findsOneWidget);
  });
}
