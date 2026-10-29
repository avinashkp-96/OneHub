import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  final now = DateTime(2026, 10, 29, 12, 0);
  String ago(Duration d) => now.subtract(d).toUtc().toIso8601String();

  List<Map<String, dynamic>> sample() => [
        {
          'id': 'n1',
          'event': 'BID_RECEIVED',
          'message': 'New bid received from Rajesh Electricals: ₹300–₹450',
          'createdAt': ago(const Duration(minutes: 10)),
          'readAt': null,
        },
        {
          'id': 'n2',
          'event': 'REQUEST_ACCEPTED',
          'message': 'Rajesh Electricals accepted your request',
          'createdAt': ago(const Duration(hours: 3)),
          'readAt': null,
        },
        {
          'id': 'n3',
          'event': 'JOB_COMPLETED',
          'message': 'Job completed. Rate your service provider.',
          'createdAt': ago(const Duration(days: 1, hours: 2)),
          'readAt': ago(const Duration(days: 1)),
        },
      ];

  late List<String> calls;

  ApiClient fakeApi({List<Map<String, dynamic>>? items, bool fail = false}) {
    calls = [];
    return ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (fail) return http.Response(jsonEncode({'message': 'down'}), 500);
        if (request.method == 'GET' && request.url.path == '/notifications') {
          // utf-8 like the real API: the default (latin-1) cannot carry ₹.
          return http.Response.bytes(
              utf8.encode(jsonEncode(items ?? sample())), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, ApiClient api) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: NotificationsScreen(api: api, clock: () => now),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the notifications from the API with titles and times',
      (tester) async {
    await pumpScreen(tester, fakeApi());

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsNothing);
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text('Notifications')),
        findsOneWidget,
        reason: 'the page name is in the top bar, not the body');
    expect(calls, contains('GET /notifications'));

    expect(find.text('New bid'), findsOneWidget);
    expect(find.text('New bid received from Rajesh Electricals: ₹300–₹450'),
        findsOneWidget);
    expect(find.text('10 min ago'), findsOneWidget);
    expect(find.text('Request accepted'), findsOneWidget);
    expect(find.text('3 hours ago'), findsOneWidget);
    expect(find.text('Job completed'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
  });

  testWidgets('counts unread and marks them with a dot', (tester) async {
    await pumpScreen(tester, fakeApi());

    expect(find.text('2 unread'), findsOneWidget);
    expect(find.byKey(const Key('unread-dot')), findsNWidgets(2));
  });

  testWidgets('tapping one marks it read and saves that', (tester) async {
    await pumpScreen(tester, fakeApi());

    await tester.tap(find.text('New bid'));
    await tester.pumpAndSettle();

    expect(find.text('1 unread'), findsOneWidget);
    expect(calls, contains('PATCH /notifications/n1/read'));
  });

  testWidgets('tapping an already read one saves nothing', (tester) async {
    await pumpScreen(tester, fakeApi());

    await tester.tap(find.text('Job completed'));
    await tester.pumpAndSettle();

    expect(calls.where((c) => c.startsWith('PATCH')), isEmpty);
  });

  testWidgets('Mark all as read clears every dot and saves that',
      (tester) async {
    await pumpScreen(tester, fakeApi());

    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();

    expect(find.text("You're all caught up."), findsOneWidget);
    expect(find.text('Mark all as read'), findsNothing);
    expect(find.byKey(const Key('unread-dot')), findsNothing);
    expect(calls, contains('PATCH /notifications/read-all'));
  });

  testWidgets('shows an empty state when there are none', (tester) async {
    await pumpScreen(tester, fakeApi(items: []));

    expect(find.text('No notifications yet.'), findsOneWidget);
    expect(find.text("You're all caught up."), findsOneWidget);
  });

  testWidgets('says so when the list cannot load', (tester) async {
    await pumpScreen(tester, fakeApi(fail: true));

    expect(find.textContaining('Could not load notifications'), findsOneWidget);
  });

  test('time labels', () {
    String label(Duration d) => relativeTimeLabel(now.subtract(d), now);
    expect(label(const Duration(seconds: 20)), 'Just now');
    expect(label(const Duration(minutes: 5)), '5 min ago');
    expect(label(const Duration(hours: 1)), '1 hour ago');
    expect(label(const Duration(hours: 5)), '5 hours ago');
    expect(label(const Duration(hours: 30)), 'Yesterday');
    expect(label(const Duration(days: 4)), '4 days ago');
    expect(relativeTimeLabel(DateTime(2026, 10, 12), now), '12 Oct');
  });

  test('unknown events get a generic title and icon', () {
    final n = OneHubNotification.fromJson({
      'id': 'x',
      'event': 'SOMETHING_NEW',
      'message': 'Hello',
      'createdAt': now.toUtc().toIso8601String(),
      'readAt': null,
    });
    expect(n.title, 'Notification');
    expect(n.icon, OneHubIcons.notification);
    expect(n.unread, isTrue);
  });
}
