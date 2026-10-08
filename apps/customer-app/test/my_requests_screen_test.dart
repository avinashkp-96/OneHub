import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/requirements/bid_list_screen.dart';
import 'package:onehub_customer/features/requirements/my_requests_screen.dart';
import 'package:onehub_customer/features/requirements/rating_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.light(), home: const MyRequestsScreen()),
    );
  }

  testWidgets('shows the heading immediately, with the list loading',
      (tester) async {
    installFakeApi({'GET /requirements/mine': (_) => []});
    await pumpScreen(tester);

    expect(find.text('My requests'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('the whole screen is wrapped in PageGlow', (tester) async {
    installFakeApi({'GET /requirements/mine': (_) => []});
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.byType(PageGlow), findsOneWidget);
  });

  testWidgets('labels every request status', (tester) async {
    installFakeApi({
      'GET /requirements/mine': (_) => [
            requirementJson('r1', 'Sent job', 'SENT'),
            requirementJson('r2', 'Accepted job', 'ACCEPTED'),
            requirementJson('r3', 'Rejected job', 'REJECTED'),
            requirementJson('r4', 'Bid job', 'BID_RECEIVED',
                bids: [bidJson('b1'), bidJson('b2')]),
            requirementJson('r5', 'Confirmed job', 'CONFIRMED'),
            requirementJson('r6', 'Completed job', 'COMPLETED'),
            requirementJson('r7', 'Cancelled job', 'CANCELLED'),
            requirementJson('r8', 'Expired job', 'EXPIRED'),
          ],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    for (final label in [
      'SENT',
      'ACCEPTED',
      'REJECTED',
      '2 BIDS',
      'CONFIRMED',
      'COMPLETED',
      'CANCELLED',
      'EXPIRED'
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('shows an empty state when there are no requests',
      (tester) async {
    installFakeApi({'GET /requirements/mine': (_) => []});
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(
        find.text("You haven't posted any requirements yet."), findsOneWidget);
  });

  testWidgets('shows an error when the requests cannot be loaded',
      (tester) async {
    installFakeApi(
        {'GET /requirements/mine': (_) => const FakeError(500, 'down')});
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load your requests'), findsOneWidget);
  });

  testWidgets(
      'opening an in-progress request shows its bids, then reloads on return',
      (tester) async {
    final fake = installFakeApi({
      'GET /requirements/mine': (_) => [
            requirementJson('r1', 'Fan job', 'BID_RECEIVED',
                bids: [bidJson('b1')])
          ],
      'GET /requirements/r1/bids': (_) => [bidJson('b1')],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fan job'));
    await tester.pumpAndSettle();
    expect(find.byType(BidListScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(BidListScreen), findsNothing);
    expect(fake.calls.where((c) => c == 'GET /requirements/mine').length, 2);
  });

  testWidgets(
      'opening a completed job that is not rated yet opens the rating screen',
      (tester) async {
    installFakeApi({
      'GET /requirements/mine': (_) => [
            requirementJson('r2', 'Paint job', 'COMPLETED',
                bids: [bidJson('b9', confirmed: true)]),
          ],
      'GET /ratings/requirement/r2': (_) => null,
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paint job'));
    await tester.pumpAndSettle();

    expect(find.byType(RatingScreen), findsOneWidget);
  });

  testWidgets('a completed job that is already rated says so instead',
      (tester) async {
    installFakeApi({
      'GET /requirements/mine': (_) => [
            requirementJson('r2', 'Paint job', 'COMPLETED',
                bids: [bidJson('b9', confirmed: true)]),
          ],
      'GET /ratings/requirement/r2': (_) => {'id': 'rating-1'},
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paint job'));
    await tester.pumpAndSettle();

    expect(find.text("You've already rated this job."), findsOneWidget);
    expect(find.byType(RatingScreen), findsNothing);
  });

  testWidgets('a completed job with no confirmed bid does nothing when tapped',
      (tester) async {
    final fake = installFakeApi({
      'GET /requirements/mine': (_) => [
            requirementJson('r2', 'Paint job', 'COMPLETED',
                bids: [bidJson('b9')])
          ],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Paint job'));
    await tester.pumpAndSettle();

    expect(find.byType(RatingScreen), findsNothing);
    expect(fake.calls.where((c) => c.contains('/ratings/')), isEmpty);
  });
}
