import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/bids/price_range_screen.dart';
import 'package:onehub_provider/features/requirements/incoming_requests_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ApiClient reads the stored token; there is no secure-storage plugin in
  // widget tests, so answer its channel with "no token".
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  late List<String> calls;

  ApiClient fakeClient(
      {List<Map<String, dynamic>>? requests, bool failAccept = false}) {
    calls = [];
    final items = requests ??
        [
          {
            'id': 'r1',
            'subServiceId': 's1',
            'description': 'Ceiling fan making a rattling noise',
            'photoUrls': ['a.jpg', 'b.jpg'],
            'status': 'SENT',
          },
          {
            'id': 'r2',
            'subServiceId': 's2',
            'description': 'Fix a leaking tap',
            'photoUrls': [],
            'status': 'SENT'
          },
        ];
    return ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path == '/requirements/incoming') {
          return http.Response(jsonEncode(items), 200);
        }
        if (request.url.path.endsWith('/accept') && failAccept) {
          return http.Response(jsonEncode({'message': 'Already taken'}), 409);
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, ApiClient client) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
          theme: OneHubTheme.dark(),
          home: IncomingRequestsScreen(client: client)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'lists each request with its photo count and accept/reject actions',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsNothing);
    expect(find.text('Incoming requests'), findsOneWidget);
    expect(find.text('Ceiling fan making a rattling noise'), findsOneWidget);
    expect(find.text('Fix a leaking tap'), findsOneWidget);
    expect(find.text('2 PHOTOS'), findsOneWidget);
    expect(find.widgetWithText(PrimaryCta, 'Accept'), findsNWidgets(2));
    expect(find.widgetWithText(OutlinedButton, 'Reject'), findsNWidgets(2));
  });

  testWidgets('shows an empty state when there are no requests',
      (tester) async {
    await pumpScreen(tester, fakeClient(requests: []));

    expect(find.text('No new requests right now.'), findsOneWidget);
  });

  testWidgets('shows an error when the list cannot be loaded', (tester) async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async =>
          http.Response(jsonEncode({'message': 'Server down'}), 500)),
    );
    await pumpScreen(tester, client);

    expect(find.textContaining('Could not load incoming requests'),
        findsOneWidget);
  });

  testWidgets('rejecting a request calls the API and reloads the list',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject').first);
    await tester.pumpAndSettle();

    expect(calls, contains('PATCH /requirements/r1/reject'));
    expect(calls.where((c) => c == 'GET /requirements/incoming').length, 2);
  });

  testWidgets('accepting a request opens the price range screen for it',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.tap(find.widgetWithText(PrimaryCta, 'Accept').first);
    await tester.pumpAndSettle();

    expect(calls, contains('PATCH /requirements/r1/accept'));
    expect(find.byType(PriceRangeScreen), findsOneWidget);
    expect(find.text('Your price range'), findsOneWidget);
  });

  testWidgets('shows an error and stays on the list when accepting fails',
      (tester) async {
    await pumpScreen(tester, fakeClient(failAccept: true));

    await tester.tap(find.widgetWithText(PrimaryCta, 'Accept').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not accept'), findsOneWidget);
    expect(find.byType(PriceRangeScreen), findsNothing);
  });
}
