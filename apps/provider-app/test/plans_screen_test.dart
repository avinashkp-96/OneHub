import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/earnings/earnings_screen.dart';
import 'package:onehub_provider/features/plans/plans_screen.dart';
import 'package:onehub_provider/features/profile/profile_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  late List<String> calls;
  late List<Map<String, dynamic>> putBodies;

  ApiClient fakeClient({
    Object? subscription = const {
      'providerId': 'p1',
      'plan': 'MONTHLY_99',
      'cycleLimit': 5,
      'cycleUsed': 2,
    },
    bool noProvider = false,
    bool failPut = false,
    bool failLoad = false,
  }) {
    calls = [];
    putBodies = [];
    return ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (failLoad) {
          return http.Response(jsonEncode({'message': 'down'}), 500);
        }
        if (request.url.path == '/users/me') {
          return http.Response(
              jsonEncode({
                'id': 'u1',
                'provider': noProvider ? null : {'id': 'p1'}
              }),
              200);
        }
        if (request.url.path == '/providers/p1/subscription') {
          if (request.method == 'PUT') {
            if (failPut) {
              return http.Response(jsonEncode({'message': 'Not allowed'}), 403);
            }
            putBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(jsonEncode({'ok': true}), 200);
          }
          // An empty body is what Nest sends for "no subscription yet".
          return http.Response(
              subscription == null ? '' : jsonEncode(subscription), 200);
        }
        return http.Response(jsonEncode({}), 404);
      }),
    );
  }

  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpScreen(WidgetTester tester, ApiClient client) async {
    tallView(tester);
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PlansScreen(client: client))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the current plan, its usage and all three plans',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('CURRENT PLAN'), findsOneWidget);
    expect(find.text('2 of 5 unlocks used this month'), findsOneWidget);
    for (final p in planOptions) {
      expect(find.text(p.name), findsWidgets);
    }
    expect(find.text('CURRENT'), findsOneWidget);
    expect(calls,
        containsAll(['GET /users/me', 'GET /providers/p1/subscription']));
  });

  testWidgets('treats no subscription as pay per service', (tester) async {
    await pumpScreen(tester, fakeClient(subscription: null));

    expect(find.text('Pay per service'), findsWidgets);
    expect(find.textContaining('unlocks used'), findsNothing);
    expect(find.byKey(const Key('plan-usage')), findsNothing);
  });

  testWidgets('Switch plan stays disabled until another plan is picked',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    final before = tester
        .widget<PrimaryCta>(find.widgetWithText(PrimaryCta, 'Switch plan'));
    expect(before.onPressed, isNull);

    await tester.tap(find.text('Monthly 299'));
    await tester.pump();

    final after = tester
        .widget<PrimaryCta>(find.widgetWithText(PrimaryCta, 'Switch plan'));
    expect(after.onPressed, isNotNull);
  });

  testWidgets('switching asks first, then saves and confirms', (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.tap(find.text('Monthly 299'));
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryCta, 'Switch plan'));
    await tester.pumpAndSettle();
    expect(find.text('Switch to Monthly 299?'), findsOneWidget);
    expect(putBodies, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Switch'));
    await tester.pumpAndSettle();

    expect(putBodies, [
      {'plan': 'MONTHLY_299'}
    ]);
    expect(find.text('Plan changed to Monthly 299.'), findsOneWidget);
    expect(find.text('0 of 10 unlocks used this month'), findsOneWidget);
  });

  testWidgets('cancelling the dialog changes nothing', (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.tap(find.text('Monthly 299'));
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryCta, 'Switch plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(putBodies, isEmpty);
    expect(find.text('2 of 5 unlocks used this month'), findsOneWidget);
  });

  testWidgets('shows the server error and keeps the old plan', (tester) async {
    await pumpScreen(tester, fakeClient(failPut: true));

    await tester.tap(find.text('Monthly 299'));
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryCta, 'Switch plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Switch'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not change your plan'), findsOneWidget);
    expect(find.text('2 of 5 unlocks used this month'), findsOneWidget);
  });

  testWidgets('shows an error when the plan cannot be loaded', (tester) async {
    await pumpScreen(tester, fakeClient(failLoad: true));

    expect(find.textContaining('Could not load your plan'), findsOneWidget);
    expect(find.widgetWithText(PrimaryCta, 'Switch plan'), findsNothing);
  });

  testWidgets('an account with no provider profile gets a clear error',
      (tester) async {
    await pumpScreen(tester, fakeClient(noProvider: true));

    expect(find.textContaining('no provider profile'), findsOneWidget);
  });

  testWidgets('Profile and Earnings link to the plans screen', (tester) async {
    tallView(tester);

    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: ProfileScreen(client: fakeClient()),
    ));
    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();
    expect(find.byType(PlansScreen), findsOneWidget);

    // Drop the pushed route before mounting the next screen.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: const EarningsScreen(),
    ));
    expect(find.text('Manage plan'), findsOneWidget);
  });
}
