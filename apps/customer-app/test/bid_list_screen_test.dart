import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/requirements/bid_list_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
          theme: OneHubTheme.light(),
          home: const BidListScreen(requirementId: 'req-1')),
    );
  }

  testWidgets('shows the heading immediately, with the bid list loading',
      (tester) async {
    installFakeApi({'GET /requirements/req-1/bids': (_) => []});
    await pumpScreen(tester);

    expect(find.text('Bids received'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('is wrapped in PageGlow, with no bid tile GlowCards',
      (tester) async {
    installFakeApi({
      'GET /requirements/req-1/bids': (_) => [bidJson('b1')],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsNothing);
  });

  testWidgets('shows each bid with its price range and contact status',
      (tester) async {
    installFakeApi({
      'GET /requirements/req-1/bids': (_) => [
            bidJson('b1', min: 500, max: 900, contactUnlocked: true),
            bidJson('b2',
                min: 600, max: 1000, refinedMin: 650, refinedMax: 800),
            bidJson('b3',
                min: 300, max: 400, confirmed: true, contactUnlocked: true),
          ],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('₹500–₹900'), findsOneWidget);
    expect(find.text('₹650–₹800'), findsOneWidget,
        reason: 'a refined range replaces the initial one');
    expect(find.text('₹300–₹400'), findsOneWidget);
    expect(find.text('CONTACTED YOU'), findsNWidgets(2));
    expect(find.text('NOT YET CONTACTED'), findsOneWidget);
    expect(find.text('CONFIRMED'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Confirm'), findsNWidgets(2));
  });

  testWidgets('shows an empty state when there are no bids', (tester) async {
    installFakeApi({'GET /requirements/req-1/bids': (_) => []});
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('No bids yet'), findsOneWidget);
  });

  testWidgets('shows an error when the bids cannot be loaded', (tester) async {
    installFakeApi(
        {'GET /requirements/req-1/bids': (_) => const FakeError(500, 'down')});
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load bids'), findsOneWidget);
  });

  testWidgets('confirming a provider calls the API and reloads the list',
      (tester) async {
    var confirmed = false;
    final fake = installFakeApi({
      'GET /requirements/req-1/bids': (_) =>
          [bidJson('b1', confirmed: confirmed)],
      'PATCH /bids/b1/confirm': (_) {
        confirmed = true;
        return {'ok': true};
      },
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('PATCH /bids/b1/confirm'));
    expect(
        fake.calls.where((c) => c == 'GET /requirements/req-1/bids').length, 2);
    expect(find.text('CONFIRMED'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Confirm'), findsNothing);
  });

  testWidgets('shows an error when confirming fails', (tester) async {
    installFakeApi({
      'GET /requirements/req-1/bids': (_) => [bidJson('b1')],
      'PATCH /bids/b1/confirm': (_) =>
          const FakeError(409, 'Already confirmed'),
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Could not confirm this provider'), findsOneWidget);
  });
}
