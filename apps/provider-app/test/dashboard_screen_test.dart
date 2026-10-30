import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/dashboard/dashboard_screen.dart';
import 'package:onehub_provider/features/earnings/earnings_screen.dart';
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
      'shows the overview card and the work, wallet and certification sections',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Earned this month'), findsOneWidget);
    expect(find.text(dummyEarnedMonth), findsOneWidget);
    expect(find.text('Jobs done'), findsOneWidget);
    expect(find.text('Rating'), findsOneWidget);
    expect(find.text('NEW REQUESTS'), findsNothing,
        reason: 'the Incoming requests card already shows that count');
    expect(find.text('ACTIVE JOBS'), findsNothing);
    expect(find.text('Incoming requests'), findsOneWidget);
    expect(find.text('Active jobs'), findsOneWidget);
    expect(find.text('Wallet balance'), findsOneWidget);
    expect(find.text('Get certified'), findsOneWidget);
  });

  testWidgets(
      'the blue overview card holds the figures; the name, toggle and bell sit above it',
      (tester) async {
    await pumpScreen(tester);

    final card = find.byKey(const Key('overview-card'));
    final decoration =
        tester.widget<Container>(card).decoration as BoxDecoration;
    expect((decoration.gradient as LinearGradient).colors,
        [OneHubColors.primary, OneHubColors.primaryGradientEnd]);
    for (final inside in [
      find.text(dummyEarnedMonth),
      find.text('Jobs done'),
      find.text('Rating'),
    ]) {
      expect(find.descendant(of: card, matching: inside), findsOneWidget);
    }
    for (final outside in [
      find.text('Asha'),
      find.text('Online'),
      find.byType(NotificationBell),
    ]) {
      expect(find.descendant(of: card, matching: outside), findsNothing);
      expect(tester.getRect(outside).bottom,
          lessThan(tester.getRect(card).top));
    }
    expect(find.byType(GlowCard), findsNothing);
  });

  testWidgets('the overview card paints its background pattern',
      (tester) async {
    await pumpScreen(tester);

    final pattern = find.byKey(const Key('overview-pattern'));
    expect(
        find.descendant(
            of: find.byKey(const Key('overview-card')), matching: pattern),
        findsOneWidget);
    expect(tester.getSize(pattern),
        tester.getSize(find.byKey(const Key('overview-card'))));
  });

  test('rings fade from the innermost outwards', () {
    expect(ringOpacity(0), closeTo(0.24, 1e-9));
    expect(ringOpacity(1), closeTo(0.02, 1e-9));
    expect(ringOpacity(0.25), greaterThan(ringOpacity(0.5)));
    expect(ringOpacity(0.5), greaterThan(ringOpacity(0.75)));
  });

  testWidgets('the jobs done and rating strip is opaque', (tester) async {
    await pumpScreen(tester);

    final strip = tester.widget<Container>(
        find.byKey(const Key('overview-stats')));
    final color = (strip.decoration as BoxDecoration).color!;
    expect(color, const Color(0xFF528EF8));
  });

  testWidgets('the rating star is white', (tester) async {
    await pumpScreen(tester);

    final stars = tester.widgetList<Icon>(find.descendant(
        of: find.byKey(const Key('overview-stats')),
        matching: find.byWidgetPredicate((w) =>
            w is Icon &&
            (w.icon == OneHubIcons.starFilled ||
                w.icon == OneHubIcons.starOutline))));
    expect(stars.single.color, Colors.white);
  });

  testWidgets('two layers peek out below the overview card', (tester) async {
    await pumpScreen(tester);

    final cardRect = tester.getRect(find.byKey(const Key('overview-card')));
    final stack = find.byKey(const Key('overview-stack'));
    final layers = tester
        .widgetList<Positioned>(
            find.descendant(of: stack, matching: find.byType(Positioned)))
        .where((p) => p.left != 0)
        .toList();
    expect(layers, hasLength(2));
    final stackRect = tester.getRect(stack);
    expect(stackRect.bottom, greaterThan(cardRect.bottom));
  });

  testWidgets('the wallet button on the card opens Earnings', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Earnings'));
    await tester.pumpAndSettle();

    expect(find.byType(EarningsScreen), findsOneWidget);
  });

  testWidgets('Your work shows its two cards side by side', (tester) async {
    await pumpScreen(tester);

    final requests = tester.getRect(find.text('Incoming requests'));
    final jobs = tester.getRect(find.text('Active jobs'));
    expect(requests.top, jobs.top);
    expect(requests.left, lessThan(jobs.left));
    expect(find.text('3 NEW'), findsOneWidget);
    expect(find.text('2 ACTIVE'), findsOneWidget);
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

  testWidgets('the header pill and bell are bright on the dark theme',
      (tester) async {
    await pumpScreen(tester);

    final online = tester.widget<Text>(find.text('Online'));
    expect(online.style!.color, OneHubColors.textPrimaryDark);
    final dot = find.descendant(
        of: find.ancestor(of: find.text('Online'), matching: find.byType(Row)),
        matching: find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle));
    expect(
        (tester.widget<Container>(dot.first).decoration as BoxDecoration)
            .color,
        onlineGreenDark);
    final bell =
        tester.widget<Icon>(find.byIcon(OneHubIcons.notification)).color;
    expect(bell, OneHubColors.textPrimaryDark);

    await tester.tap(find.text('Online'));
    await tester.pump();
    expect(tester.widget<Text>(find.text('Offline')).style!.color,
        OneHubColors.textSecondaryDark);
  });

  testWidgets('tapping the status toggle switches between online and offline',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Online'));
    await tester.pump();
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Online'), findsNothing);

    await tester.tap(find.text('Offline'));
    await tester.pump();
    expect(find.text('Online'), findsOneWidget);
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

  group('summary card', () {
    Map<String, dynamic> job(String status,
            {bool mine = true, bool bid = true}) =>
        {
          'id': 'r-$status-$mine-$bid',
          'subServiceId': 's1',
          'description': 'Fan repair',
          'photoUrls': [],
          'status': status,
          'bids': [
            if (bid)
              {
                'id': 'b1',
                'providerId': 'p1',
                'initialMinPrice': 300,
                'initialMaxPrice': 500,
                'contactUnlocked': true,
                'confirmed': mine,
              }
          ],
        };

    // Serves the rating summary and the provider's requests; a null body
    // makes that route fail.
    ApiClient summaryClient({Object? ratings, Object? jobs}) => ApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((request) async {
            http.Response json(Object? body) => http.Response.bytes(
                utf8.encode(jsonEncode(body)), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
            switch (request.url.path) {
              case '/ratings/mine':
                return ratings == null
                    ? http.Response('{}', 500)
                    : json(ratings);
              case '/requirements/incoming':
                return jobs == null ? http.Response('{}', 500) : json(jobs);
            }
            return json([]);
          }),
        );

    Future<void> pumpWith(WidgetTester tester, ApiClient client) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => 'token',
      );
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: OneHubTheme.dark(), home: DashboardScreen(client: client)));
      await tester.pumpAndSettle();
    }

    testWidgets('counts only completed jobs where this provider was chosen',
        (tester) async {
      await pumpWith(
          tester,
          summaryClient(ratings: {
            'averageRating': 4.75,
            'ratingCount': 12
          }, jobs: [
            job('COMPLETED'),
            job('COMPLETED'),
            job('COMPLETED', mine: false),
            job('COMPLETED', bid: false),
            job('CONFIRMED'),
            job('BID_RECEIVED'),
          ]));

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Jobs done'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.byIcon(OneHubIcons.starFilled), findsOneWidget);
      expect(find.text(dummyEarnedMonth), findsOneWidget);
    });

    testWidgets('a new provider shows 0 jobs and New, with no star',
        (tester) async {
      await pumpWith(
          tester,
          summaryClient(
              ratings: {'averageRating': 0, 'ratingCount': 0}, jobs: []));

      expect(find.text('0'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.byIcon(OneHubIcons.starFilled), findsNothing);
    });

    testWidgets('a failed rating call leaves its placeholder; jobs still load',
        (tester) async {
      await pumpWith(tester, summaryClient(jobs: [job('COMPLETED')]));

      expect(find.text('–'), findsOneWidget);
      expect(find.text('Rating'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a failed jobs call leaves its placeholder; rating still loads',
        (tester) async {
      await pumpWith(tester,
          summaryClient(ratings: {'averageRating': 4, 'ratingCount': 3}));

      expect(find.text('4.0'), findsOneWidget);
      expect(find.text('–'), findsOneWidget);
      expect(find.text('Jobs done'), findsOneWidget);
    });
  });
}
