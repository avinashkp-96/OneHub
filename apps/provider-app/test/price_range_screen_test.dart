import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/bids/price_range_screen.dart';
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

  ApiClient fakeClient({bool failUnlock = false}) {
    calls = [];
    return ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path == '/requirements/r1/bids') {
          return http.Response(jsonEncode({'id': 'b1'}), 200);
        }
        if (request.url.path.endsWith('/unlock-contact') && failUnlock) {
          return http.Response(jsonEncode({'message': 'Payment failed'}), 402);
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
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => PriceRangeScreen(
                          requirementId: 'r1', client: client)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> submitBid(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 500'), '500');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 1200'), '1200');
    await tester.tap(find.widgetWithText(PrimaryCta, 'Submit Bid'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts with the price fields and a Submit Bid button',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Your price range'), findsOneWidget);
    expect(find.widgetWithText(PrimaryCta, 'Submit Bid'), findsOneWidget);
    expect(find.text('Update Bid'), findsNothing);
  });

  testWidgets('rejects a bid with missing prices', (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.tap(find.widgetWithText(PrimaryCta, 'Submit Bid'));
    await tester.pump();

    expect(find.text('Enter a valid min and max price.'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('submitting moves to the unlock step with Update Bid disabled',
      (tester) async {
    await pumpScreen(tester, fakeClient());
    await submitBid(tester);

    expect(calls, contains('POST /requirements/r1/bids'));
    expect(find.text('Pay ₹50 to Contact Customer'), findsOneWidget);
    expect(find.widgetWithText(PrimaryCta, 'Submit Bid'), findsNothing);
    final update = tester
        .widget<PrimaryCta>(find.widgetWithText(PrimaryCta, 'Update Bid'));
    expect(update.onPressed, isNull);
  });

  testWidgets('unlocking the contact enables Update Bid', (tester) async {
    await pumpScreen(tester, fakeClient());
    await submitBid(tester);

    await tester.tap(find.text('Pay ₹50 to Contact Customer'));
    await tester.pumpAndSettle();

    expect(calls, contains('POST /bids/b1/unlock-contact'));
    expect(find.text('CONTACT UNLOCKED'), findsOneWidget);
    final update = tester
        .widget<PrimaryCta>(find.widgetWithText(PrimaryCta, 'Update Bid'));
    expect(update.onPressed, isNotNull);
  });

  testWidgets('shows an error and keeps the pay button when unlocking fails',
      (tester) async {
    await pumpScreen(tester, fakeClient(failUnlock: true));
    await submitBid(tester);

    await tester.tap(find.text('Pay ₹50 to Contact Customer'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not unlock contact'), findsOneWidget);
    expect(find.text('Pay ₹50 to Contact Customer'), findsOneWidget);
  });

  testWidgets('updating the bid sends the refined range and closes the screen',
      (tester) async {
    await pumpScreen(tester, fakeClient());
    await submitBid(tester);
    await tester.tap(find.text('Pay ₹50 to Contact Customer'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '500'), '600');
    await tester.tap(find.widgetWithText(PrimaryCta, 'Update Bid'));
    await tester.pumpAndSettle();

    expect(calls, contains('PATCH /bids/b1/refine'));
    expect(find.byType(PriceRangeScreen), findsNothing);
  });
}
