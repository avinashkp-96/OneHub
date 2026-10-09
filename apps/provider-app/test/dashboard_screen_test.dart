import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_provider/features/dashboard/dashboard_screen.dart';
import 'package:onehub_provider/features/profile/profile_screen.dart';
import 'package:onehub_provider/features/requirements/active_jobs_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        routes: {
          '/incoming-requests': (_) =>
              const Scaffold(body: Text('incoming requests stub'))
        },
        home: const DashboardScreen(),
      ),
    );
  }

  testWidgets(
      'shows the greeting, summary and the work, wallet and certification sections',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.text('Hello, Asha'), findsOneWidget);
    expect(find.text('● ONLINE'), findsOneWidget);
    expect(find.text("TODAY'S SUMMARY"), findsOneWidget);
    expect(find.text('NEW REQUESTS'), findsOneWidget);
    expect(find.text('ACTIVE JOBS'), findsOneWidget);
    expect(find.text('EARNED TODAY'), findsOneWidget);
    expect(find.text('Incoming requests'), findsOneWidget);
    expect(find.text('Active jobs'), findsOneWidget);
    expect(find.text('Wallet balance'), findsOneWidget);
    expect(find.text('Get certified'), findsOneWidget);
  });

  testWidgets('only the summary is a GlowCard; the rest are plain cards',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(GlowCard), findsOneWidget);
  });

  testWidgets('section cards clip their ink ripple to the theme card radius',
      (tester) async {
    await pumpScreen(tester);

    final inkWells = tester.widgetList<InkWell>(
      find.descendant(of: find.byType(Card), matching: find.byType(InkWell)),
    );
    expect(inkWells, isNotEmpty);
    for (final inkWell in inkWells) {
      expect(inkWell.borderRadius,
          BorderRadius.circular(OneHubTheme.radiusFormCard));
    }
  });

  testWidgets('the bottom nav has 4 items with Home selected', (tester) async {
    await pumpScreen(tester);

    final navBar = tester.widget<CurvedNavBar>(find.byType(CurvedNavBar));
    expect(navBar.items.map((i) => i.label),
        ['Home', 'Requests', 'Jobs', 'Profile']);
    expect(navBar.selectedIndex, 0);
  });

  testWidgets('the Incoming requests tile opens the incoming requests route',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Incoming requests'));
    await tester.pumpAndSettle();

    expect(find.text('incoming requests stub'), findsOneWidget);
  });

  testWidgets('the Requests nav item opens the incoming requests route',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.descendant(
        of: find.byType(CurvedNavBar),
        matching: find.byIcon(OneHubIcons.work)));
    await tester.pumpAndSettle();

    expect(find.text('incoming requests stub'), findsOneWidget);
  });

  testWidgets('the Active jobs tile opens the active jobs screen',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Active jobs'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ActiveJobsScreen), findsOneWidget);
  });

  testWidgets('the Jobs nav item opens the active jobs screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.descendant(
        of: find.byType(CurvedNavBar),
        matching: find.byIcon(OneHubIcons.documentList)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ActiveJobsScreen), findsOneWidget);
  });

  testWidgets('the Profile nav item opens the profile screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.descendant(
        of: find.byType(CurvedNavBar),
        matching: find.byIcon(OneHubIcons.profile)));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('tapping the status badge toggles between online and offline',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('● ONLINE'));
    await tester.pump();
    expect(find.text('● OFFLINE'), findsOneWidget);
    expect(find.text('● ONLINE'), findsNothing);

    await tester.tap(find.text('● OFFLINE'));
    await tester.pump();
    expect(find.text('● ONLINE'), findsOneWidget);
  });

  testWidgets('the notification bell opens the notifications list',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(OneHubIcons.notification));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('New request nearby'), findsOneWidget);
    expect(find.text('2 unread'), findsOneWidget);
  });
}
