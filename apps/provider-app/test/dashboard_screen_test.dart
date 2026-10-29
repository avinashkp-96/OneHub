import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/dashboard/dashboard_screen.dart';
import 'package:onehub_provider/features/home/home_shell.dart';
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

  testWidgets(
      'with a tab handler, the job tiles switch tabs instead of pushing',
      (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final opened = <int>[];
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(),
        home: DashboardScreen(onOpenTab: opened.add)));

    await tester.tap(find.text('Incoming requests'));
    await tester.tap(find.text('Active jobs'));
    await tester.pumpAndSettle();

    expect(opened, [HomeTab.requests, HomeTab.jobs]);
    expect(find.byType(ActiveJobsScreen), findsNothing);
  });

  testWidgets('the Incoming requests tile opens the incoming requests route',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Incoming requests'));
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

  testWidgets(
      'the bell shows the unread dot and opens the real notifications list',
      (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async => http.Response(
          jsonEncode([
            {
              'id': 'n1',
              'event': 'NEW_REQUEST',
              'message': 'New job request: Switchboard Repair',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              'readAt': null,
            }
          ]),
          200)),
    );
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(), home: DashboardScreen(client: client)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bell-unread-dot')), findsOneWidget);

    await tester.tap(find.byIcon(OneHubIcons.notification));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.text('New job request'), findsOneWidget);
    expect(find.text('New job request: Switchboard Repair'), findsOneWidget);
    expect(find.text('1 unread'), findsOneWidget);
  });
}
