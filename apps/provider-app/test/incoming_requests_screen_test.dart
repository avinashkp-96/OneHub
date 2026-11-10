import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/bids/price_range_screen.dart';
import 'package:onehub_provider/features/requirements/incoming_requests_screen.dart';
import 'package:onehub_provider/features/requirements/job_detail.dart';
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
      {List<Map<String, dynamic>>? requests}) {
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
    expect(find.byKey(const Key('request-card')), findsNWidgets(2));
    expect(find.text('PHOTOS'), findsOneWidget);
    expect(find.text('2 photos'), findsOneWidget);
    expect(find.text('NEW'), findsNWidgets(2));
    expect(find.widgetWithText(PrimaryCta, 'Send price'), findsNWidgets(2));
    expect(find.widgetWithText(OutlinedButton, 'Reject'), findsNWidgets(2));
    expect(find.text('Accept'), findsNothing);
  });

  group('customer details', () {
    Map<String, dynamic> request(Map<String, dynamic> extra) => {
          'id': 'r1',
          'subServiceId': 's1',
          'description': 'Ceiling fan making a rattling noise',
          'photoUrls': [],
          'status': 'SENT',
          ...extra,
        };

    testWidgets('shows the title in bold with the description below',
        (tester) async {
      await pumpScreen(
          tester, fakeClient(requests: [request({'title': 'Fan repair'})]));

      final title = tester.widget<Text>(find.text('Fan repair'));
      expect(title.style!.fontSize, 24);
      expect(find.text('Ceiling fan making a rattling noise'), findsOneWidget);
      expect(
          tester.getRect(find.text('Ceiling fan making a rattling noise')).top,
          greaterThan(tester.getRect(find.text('Fan repair')).top));
    });

    testWidgets('shows the customer name, place and distance',
        (tester) async {
      await pumpScreen(
          tester,
          fakeClient(requests: [
            request({
              'customerName': 'Meera Nair',
              'customerPlace': 'Kochi',
              'distanceKm': 6.74,
            })
          ]));

      expect(find.text('CUSTOMER'), findsOneWidget);
      expect(find.text('Meera Nair'), findsOneWidget);
      expect(find.text('LOCATION'), findsOneWidget);
      expect(find.text('Kochi · 6.7 km'), findsOneWidget);
    });

    testWidgets('shows when it was posted, and no typical price',
        (tester) async {
      await pumpScreen(
          tester,
          fakeClient(requests: [
            request({
              'createdAt': DateTime.now()
                  .subtract(const Duration(days: 2, hours: 1))
                  .toUtc()
                  .toIso8601String(),
              'subService': {
                'id': 's1',
                'categoryId': 'c1',
                'name': 'Fan Installation',
                'suggestedMinPrice': 250,
                'suggestedMaxPrice': 450,
              },
            })
          ]));

      expect(find.text('Posted 2 days ago'), findsOneWidget);
      expect(find.text('TYPICAL PRICE'), findsNothing);
      expect(find.text('₹250 – ₹450'), findsNothing);
    });

    Map<String, dynamic> bid({bool confirmed = false}) => {
          'id': 'b1',
          'providerId': 'p1',
          'initialMinPrice': 300,
          'initialMaxPrice': 500,
          'contactUnlocked': false,
          'confirmed': confirmed,
        };

    testWidgets('an old accept with no price yet still offers Send price',
        (tester) async {
      await pumpScreen(
          tester,
          fakeClient(requests: [
            request({'status': 'ACCEPTED', 'myResponse': 'ACCEPTED'})
          ]));

      expect(find.text('NEW'), findsOneWidget);
      expect(find.widgetWithText(PrimaryCta, 'Send price'), findsOneWidget);
    });

    testWidgets(
        "uses this provider's own answer, not the request status",
        (tester) async {
      await pumpScreen(
          tester,
          fakeClient(requests: [
            request({'status': 'ACCEPTED', 'myResponse': 'SENT'})
          ]));

      expect(find.text('NEW'), findsOneWidget,
          reason: 'another provider accepted, this one has not answered');
      expect(find.widgetWithText(PrimaryCta, 'Send price'), findsOneWidget);
    });

    testWidgets('once a price is sent there are no buttons', (tester) async {
      await pumpScreen(
          tester,
          fakeClient(requests: [
            request({
              'status': 'BID_RECEIVED',
              'myResponse': 'ACCEPTED',
              'bids': [bid()],
            })
          ]));

      expect(find.text('BID SENT'), findsOneWidget);
      expect(find.byType(PrimaryCta), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('a card with a price sent shows YOUR BID', (tester) async {
      await pumpScreen(
          tester,
          fakeClient(requests: [
            request({
              'status': 'BID_RECEIVED',
              'bids': [bid()],
            })
          ]));

      expect(find.text('YOUR BID'), findsOneWidget);
      expect(find.text('₹300 – ₹500'), findsOneWidget);
    });

    testWidgets('tapping a sent card opens its detail with the bid, no actions',
        (tester) async {
      await pumpScreen(
          tester,
          fakeClient(requests: [
            request({
              'title': 'Fan repair',
              'status': 'BID_RECEIVED',
              'customerName': 'Meera Nair',
              'preferredAt': '2026-11-05T10:00:00.000Z',
              'bids': [bid()],
            })
          ]));

      await tester.tap(find.text('Fan repair'));
      await tester.pumpAndSettle();

      expect(find.byType(RequestDetailScreen), findsOneWidget);
      expect(find.text('YOUR BID'), findsOneWidget);
      expect(find.text('₹300 – ₹500'), findsOneWidget);
      expect(find.text('PREFERRED DATE'), findsOneWidget);
      expect(find.text('Customer chooses a provider'), findsOneWidget);
      expect(find.byType(PrimaryCta), findsNothing);
    });

    testWidgets("a new request's detail keeps Reject and Send price",
        (tester) async {
      await pumpScreen(
          tester, fakeClient(requests: [request({'title': 'Fan repair'})]));

      await tester.tap(find.text('Fan repair'));
      await tester.pumpAndSettle();
      expect(find.byType(RequestDetailScreen), findsOneWidget);
      expect(find.text('YOUR BID'), findsNothing);

      await tester.tap(find.widgetWithText(PrimaryCta, 'Send price'));
      await tester.pumpAndSettle();
      expect(find.byType(RequestDetailScreen), findsNothing);
      expect(find.byType(PriceRangeScreen), findsOneWidget);
    });

    testWidgets("Reject from a new request's detail rejects and closes it",
        (tester) async {
      await pumpScreen(
          tester, fakeClient(requests: [request({'title': 'Fan repair'})]));

      await tester.tap(find.text('Fan repair'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
      await tester.pumpAndSettle();

      expect(find.byType(RequestDetailScreen), findsNothing);
      expect(calls, contains('PATCH /requirements/r1/reject'));
    });

    testWidgets('hides requests this provider rejected', (tester) async {
      await pumpScreen(
          tester,
          fakeClient(requests: [
            request({'myResponse': 'REJECTED'}),
            {...request({'myResponse': 'SENT'}), 'id': 'r2', 'title': 'Kept'},
          ]));

      expect(find.byKey(const Key('request-card')), findsOneWidget);
      expect(find.text('Kept'), findsOneWidget);
    });

    testWidgets('shows the place alone when the distance is unknown',
        (tester) async {
      await pumpScreen(
          tester,
          fakeClient(requests: [
            request({
              'customerName': 'Meera Nair',
              'customerPlace': 'Kochi',
              'distanceKm': null,
            })
          ]));

      expect(find.text('Kochi'), findsOneWidget);
      expect(find.textContaining(' km'), findsNothing);
    });

    testWidgets('shows the distance alone when the city is unknown',
        (tester) async {
      await pumpScreen(
          tester,
          fakeClient(requests: [
            request({'customerName': 'Meera Nair', 'distanceKm': 0.4})
          ]));

      expect(find.text('0.4 km'), findsOneWidget);
    });

    testWidgets('leaves out the facts row when nothing is known',
        (tester) async {
      await pumpScreen(tester, fakeClient(requests: [request({})]));

      expect(find.text('CUSTOMER'), findsNothing);
      expect(find.text('LOCATION'), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });
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
    expect(find.text('Request rejected.'), findsOneWidget);
    expect(calls.where((c) => c == 'GET /requirements/incoming').length, 2);
  });

  testWidgets(
      'Send price opens the price range screen without a separate accept',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.tap(find.widgetWithText(PrimaryCta, 'Send price').first);
    await tester.pumpAndSettle();

    expect(find.byType(PriceRangeScreen), findsOneWidget);
    expect(find.text('Your price range'), findsOneWidget);
    expect(calls.where((c) => c.startsWith('PATCH')), isEmpty);
  });

  testWidgets('coming back from the price screen reloads the list',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.tap(find.widgetWithText(PrimaryCta, 'Send price').first);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(calls.where((c) => c == 'GET /requirements/incoming').length, 2);
  });

  group('incomingStageOf', () {
    Requirement r(String status,
            {String? mine, bool hasBid = false, bool confirmed = false}) =>
        Requirement.fromJson({
          'id': 'r',
          'subServiceId': 's',
          'description': 'd',
          'status': status,
          if (mine != null) 'myResponse': mine,
          'bids': [
            if (hasBid)
              {
                'id': 'b',
                'providerId': 'p',
                'initialMinPrice': 1,
                'initialMaxPrice': 2,
                'contactUnlocked': false,
                'confirmed': confirmed,
              }
          ],
        });

    test('covers every stage', () {
      expect(incomingStageOf(r('SENT')), IncomingStage.newRequest);
      expect(incomingStageOf(r('ACCEPTED', mine: 'ACCEPTED')),
          IncomingStage.newRequest);
      expect(incomingStageOf(r('BID_RECEIVED', hasBid: true)),
          IncomingStage.bidSent);
      expect(incomingStageOf(r('CONFIRMED', hasBid: true, confirmed: true)),
          IncomingStage.selected);
      expect(incomingStageOf(r('COMPLETED', hasBid: true, confirmed: true)),
          IncomingStage.completed);
      expect(incomingStageOf(r('CONFIRMED', hasBid: true)),
          IncomingStage.notSelected);
      expect(incomingStageOf(r('CONFIRMED', mine: 'ACCEPTED')),
          IncomingStage.closed);
      expect(incomingStageOf(r('EXPIRED')), IncomingStage.closed);
    });
  });

  group('openIncomingById (notification tap)', () {
    Future<void> pumpOpener(
        WidgetTester tester, ApiClient client, String id) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () => openIncomingById(context, id, client: client),
                child: const Text('open')),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    final detailActions = find.descendant(
        of: find.byType(RequestDetailScreen),
        matching: find.widgetWithText(PrimaryCta, 'Send price'));

    testWidgets('opens the detail with Reject and Send price on a new request',
        (tester) async {
      await pumpOpener(tester, fakeClient(), 'r2');

      expect(find.byType(RequestDetailScreen), findsOneWidget);
      expect(find.text('Fix a leaking tap'), findsWidgets);
      expect(detailActions, findsOneWidget);
    });

    testWidgets('Send price closes the detail and opens the price screen',
        (tester) async {
      await pumpOpener(tester, fakeClient(), 'r1');

      await tester.tap(detailActions);
      await tester.pumpAndSettle();

      expect(find.byType(RequestDetailScreen), findsNothing);
      expect(find.byType(PriceRangeScreen), findsOneWidget);
    });

    testWidgets('Reject closes the detail and rejects through the API',
        (tester) async {
      await pumpOpener(tester, fakeClient(), 'r1');

      await tester.tap(find.descendant(
          of: find.byType(RequestDetailScreen),
          matching: find.widgetWithText(OutlinedButton, 'Reject')));
      await tester.pumpAndSettle();

      expect(find.byType(RequestDetailScreen), findsNothing);
      expect(calls, contains('PATCH /requirements/r1/reject'));
      expect(find.text('Request rejected.'), findsOneWidget);
    });

    testWidgets('a failed reject says so', (tester) async {
      final client = ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async => request.method == 'GET'
            ? http.Response(
                jsonEncode([
                  {
                    'id': 'r1',
                    'subServiceId': 's1',
                    'description': 'Fan noise',
                    'photoUrls': [],
                    'status': 'SENT'
                  }
                ]),
                200)
            : http.Response(jsonEncode({'message': 'down'}), 500)),
      );
      await pumpOpener(tester, client, 'r1');

      await tester.tap(find.descendant(
          of: find.byType(RequestDetailScreen),
          matching: find.widgetWithText(OutlinedButton, 'Reject')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not reject'), findsOneWidget);
    });

    testWidgets('a request this provider rejected counts as gone',
        (tester) async {
      await pumpOpener(
          tester,
          fakeClient(requests: [
            {
              'id': 'r1',
              'subServiceId': 's1',
              'description': 'Fan noise',
              'photoUrls': [],
              'status': 'SENT',
              'myResponse': 'REJECTED',
            }
          ]),
          'r1');

      expect(find.byType(RequestDetailScreen), findsNothing);
      expect(find.text('This request is no longer available.'), findsOneWidget);
    });

    testWidgets('says so when the requests cannot load', (tester) async {
      final client = ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient(
            (_) async => http.Response(jsonEncode({'message': 'down'}), 500)),
      );
      await pumpOpener(tester, client, 'r1');

      expect(find.textContaining('Could not open this request'), findsOneWidget);
    });
  });
}
