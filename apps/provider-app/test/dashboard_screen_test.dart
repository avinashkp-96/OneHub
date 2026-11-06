import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/business/business_details_screen.dart';
import 'package:onehub_provider/features/dashboard/dashboard_screen.dart';
import 'package:onehub_provider/features/earnings/earnings_screen.dart';
import 'package:onehub_provider/features/home/home_shell.dart';
import 'package:onehub_provider/features/requirements/active_jobs_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

/// A fake API for the home page: the provider's own record, their
/// subscription and their requests. A null [me] makes /providers/me fail; a
/// null [subscription] is an empty body (no subscription yet). [calls]
/// collects each path requested.
ApiClient homeClient({
  Map<String, dynamic>? me = const {
    'id': 'p1',
    'businessName': 'Rajesh Electricals',
  },
  Map<String, dynamic>? subscription = const {
    'plan': 'MONTHLY_99',
    'renewsAt': '2026-11-12T06:00:00.000Z',
  },
  List<Object> Function()? incoming,
  List<String>? calls,
}) =>
    ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        calls?.add(request.url.path);
        http.Response json(Object? body) => http.Response.bytes(
            utf8.encode(jsonEncode(body)), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
        switch (request.url.path) {
          case '/providers/me':
            return me == null ? http.Response('{}', 500) : json(me);
          case '/providers/p1/subscription':
            return subscription == null
                ? http.Response('', 200)
                : json(subscription);
          case '/requirements/incoming':
            return json(incoming?.call() ?? []);
          case '/ratings/mine':
            return json({'averageRating': 0, 'ratingCount': 0});
        }
        return json([]);
      }),
    );

void mockSecureStorage() =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => 'token',
    );

void main() {
  Future<void> pumpScreen(WidgetTester tester, {ApiClient? client}) async {
    mockSecureStorage();
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
        home: DashboardScreen(client: client ?? homeClient()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'shows the overview card and the work, wallet and certification sections',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Rajesh Electricals'), findsOneWidget);
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
      find.text('Rajesh Electricals'),
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

  group('Next job', () {
    final now = DateTime(2026, 11, 3, 10);

    Map<String, dynamic> request(
      String id, {
      String status = 'SENT',
      String myResponse = 'SENT',
      bool bid = false,
      bool confirmed = false,
      int postedHoursAgo = 1,
      DateTime? preferredAt,
    }) =>
        {
          'id': id,
          'subServiceId': 's1',
          'title': 'Job $id',
          'description': 'Details for $id',
          'photoUrls': [],
          'status': status,
          'myResponse': myResponse,
          'customerName': 'Meera Nair',
          'customerPlace': 'Kochi',
          'distanceKm': 6.7,
          'createdAt': now
              .subtract(Duration(hours: postedHoursAgo))
              .toUtc()
              .toIso8601String(),
          if (preferredAt != null)
            'preferredAt': preferredAt.toUtc().toIso8601String(),
          'bids': [
            if (bid)
              {
                'id': 'b-$id',
                'providerId': 'p1',
                'initialMinPrice': 350,
                'initialMaxPrice': 600,
                'contactUnlocked': false,
                'confirmed': confirmed,
              }
          ],
        };

    Map<String, dynamic> selected(String id, DateTime? at) => request(id,
        status: 'CONFIRMED',
        myResponse: 'ACCEPTED',
        bid: true,
        confirmed: true,
        preferredAt: at);

    Future<void> pumpWith(WidgetTester tester, List<Object> requests) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => 'token',
      );
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((r) async => http.Response.bytes(
            utf8.encode(jsonEncode(
                r.url.path == '/requirements/incoming' ? requests : {})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})),
      );
      await tester.pumpWidget(MaterialApp(
          theme: OneHubTheme.dark(),
          routes: {
            '/incoming-requests': (_) =>
                const Scaffold(body: Text('incoming requests stub'))
          },
          home: DashboardScreen(client: client, now: now)));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'stays hidden until the customer chooses this provider, and new requests get no card',
        (tester) async {
      await pumpWith(tester, [
        request('new'),
        request('priced', myResponse: 'ACCEPTED', bid: true),
        request('lost', status: 'CONFIRMED', myResponse: 'ACCEPTED', bid: true),
      ]);

      expect(find.text('Next job'), findsNothing);
      expect(find.text('New requests'), findsNothing);
      expect(find.text('Job new'), findsNothing);
      expect(find.text('Send price'), findsNothing);
    });

    testWidgets('Next job is the selected job due soonest, undated ones last',
        (tester) async {
      await pumpWith(tester, [
        selected('undated', null),
        selected('later', DateTime(2026, 11, 9, 9)),
        selected('soon', DateTime(2026, 11, 4, 9)),
      ]);

      expect(find.text('Next job'), findsOneWidget);
      expect(find.text('Job soon'), findsOneWidget);
      expect(find.text('Job later'), findsNothing);
      expect(find.text('Job undated'), findsNothing);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('₹350 – ₹600'), findsOneWidget);

      await tester.tap(find.text('Job soon'));
      await tester.pumpAndSettle();
      expect(find.byType(RequestDetailScreen), findsOneWidget);
      expect(find.text('Mark as Completed'), findsNothing);
    });

    testWidgets('a selected job with no date says so', (tester) async {
      await pumpWith(tester, [selected('undated', null)]);

      expect(find.text('Job undated'), findsOneWidget);
      expect(find.text('No date set'), findsOneWidget);
    });
  });

  group('Real name, counts and plan', () {
    Map<String, dynamic> request(String id,
            {String status = 'SENT',
            String myResponse = 'SENT',
            bool bid = false,
            bool confirmed = false}) =>
        {
          'id': id,
          'subServiceId': 's1',
          'title': 'Job $id',
          'description': 'Details',
          'photoUrls': [],
          'status': status,
          'myResponse': myResponse,
          'bids': [
            if (bid)
              {
                'id': 'b-$id',
                'providerId': 'p1',
                'initialMinPrice': 350,
                'initialMaxPrice': 600,
                'contactUnlocked': false,
                'confirmed': confirmed,
              }
          ],
        };

    Map<String, dynamic> selected(String id) => request(id,
        status: 'CONFIRMED', myResponse: 'ACCEPTED', bid: true, confirmed: true);

    testWidgets('shows the business name and its initial', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Rajesh Electricals'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      expect(find.text('Asha'), findsNothing);
    });

    testWidgets('falls back to Provider when the name cannot load',
        (tester) async {
      await pumpScreen(tester, client: homeClient(me: null));

      expect(find.text('Provider'), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
    });

    testWidgets(
        'counts new requests and selected jobs, leaving out rejected and priced ones',
        (tester) async {
      await pumpScreen(tester,
          client: homeClient(
              incoming: () => [
                    request('new-1'),
                    request('new-2'),
                    request('rejected', myResponse: 'REJECTED'),
                    request('priced', myResponse: 'ACCEPTED', bid: true),
                    selected('won'),
                    request('done',
                        status: 'COMPLETED',
                        myResponse: 'ACCEPTED',
                        bid: true,
                        confirmed: true),
                  ]));

      expect(find.text('2 NEW'), findsOneWidget);
      expect(find.text('1 ACTIVE'), findsOneWidget);
    });

    testWidgets('hides a badge with nothing to count', (tester) async {
      await pumpScreen(tester);

      expect(find.textContaining(' NEW'), findsNothing);
      expect(find.textContaining(' ACTIVE'), findsNothing);
    });

    testWidgets('a pushed Incoming requests page reloads the counts on return',
        (tester) async {
      var requests = <Object>[request('a'), request('b')];
      await pumpScreen(tester, client: homeClient(incoming: () => requests));
      expect(find.text('2 NEW'), findsOneWidget);

      await tester.tap(find.text('Incoming requests'));
      await tester.pumpAndSettle();
      requests = [request('a')];
      Navigator.of(tester.element(find.text('incoming requests stub'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('1 NEW'), findsOneWidget);
    });

    testWidgets('the wallet card shows the real plan and renewal date',
        (tester) async {
      await pumpScreen(tester);

      expect(find.text('MONTHLY 99'), findsOneWidget);
      expect(find.text('Renews 12 Nov'), findsOneWidget);
      expect(find.text('PRO PLAN'), findsNothing);
    });

    testWidgets('no subscription yet reads as pay per service',
        (tester) async {
      await pumpScreen(tester, client: homeClient(subscription: null));

      expect(find.text('PAY PER SERVICE'), findsOneWidget);
      expect(find.text('No monthly fee'), findsOneWidget);
    });

    testWidgets('the plan pill stays hidden when the provider cannot load',
        (tester) async {
      await pumpScreen(tester, client: homeClient(me: null));

      expect(find.text('Wallet balance'), findsOneWidget);
      expect(find.text('MONTHLY 99'), findsNothing);
      expect(find.textContaining('Renews'), findsNothing);
    });
  });

  group('Add more services banner', () {
    testWidgets('shows its message on a plain card, quieter than the overview',
        (tester) async {
      await pumpScreen(tester);

      expect(find.text('Get found in more searches'), findsOneWidget);
      expect(find.text('Add every service you offer.'), findsOneWidget);
      expect(tester.widget(find.byKey(const Key('add-services-banner'))),
          isA<Card>());
    });

    testWidgets('sits between Your work and Wallet', (tester) async {
      await pumpScreen(tester);

      final banner =
          tester.getRect(find.byKey(const Key('add-services-banner')));
      expect(tester.getBottomLeft(find.text('Active jobs')).dy,
          lessThan(banner.top));
      expect(
          banner.bottom, lessThan(tester.getTopLeft(find.text('Wallet')).dy));
    });

    testWidgets('tapping it opens Business details', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Get found in more searches'));
      await tester.pumpAndSettle();

      expect(find.byType(BusinessDetailsScreen), findsOneWidget);
    });
  });
}
