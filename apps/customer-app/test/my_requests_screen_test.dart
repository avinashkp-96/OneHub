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

  testWidgets('each request card shows the lowest bid only once there are bids',
      (tester) async {
    final sub = {
      'id': 'sub-1',
      'categoryId': 'c1',
      'name': 'Fan Installation',
    };
    installFakeApi({
      'GET /requirements/mine': (_) => [
            {
              ...requirementJson('r1', 'Fan rattles', 'BID_RECEIVED',
                  title: 'Fan repair',
                  bids: [
                    bidJson('b1', min: 600, max: 900),
                    bidJson('b2', min: 700, max: 950, refinedMin: 400, refinedMax: 650),
                  ]),
              'subService': sub,
              'createdAt': DateTime.now()
                  .subtract(const Duration(hours: 3))
                  .toUtc()
                  .toIso8601String(),
            },
            {
              ...requirementJson('r2', 'Tap drips', 'SENT',
                  title: 'Tap leak',
                  providers: [
                    {'providerId': 'p1', 'providerName': 'A', 'status': 'SENT'},
                    {'providerId': 'p2', 'providerName': 'B', 'status': 'SENT'},
                  ]),
            },
          ],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('request-card')), findsNWidgets(2));
    expect(find.text('Posted 3 hours ago'), findsOneWidget);
    expect(find.text('SERVICE'), findsNothing);
    expect(find.text('Fan Installation'), findsNothing);
    expect(find.text('LOWEST BID'), findsOneWidget);
    expect(find.text('₹400 – ₹650'), findsOneWidget,
        reason: 'a refined range counts over the initial one');
    expect(find.text('SENT TO'), findsNothing);
    expect(find.text('2 providers'), findsNothing);
  });

  testWidgets('shows the title above the description, and in the detail',
      (tester) async {
    installFakeApi({
      'GET /requirements/mine': (_) => [
            requirementJson('r1', 'The fan rattles at high speed', 'SENT',
                title: 'Fan repair'),
          ],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Fan repair'), findsOneWidget);
    expect(find.text('The fan rattles at high speed'), findsOneWidget);

    await tester.tap(find.text('Fan repair'));
    await tester.pumpAndSettle();
    expect(find.byType(RequestDetailScreen), findsOneWidget);
    expect(find.text('Fan repair'), findsOneWidget);
    expect(find.text('The fan rattles at high speed'), findsOneWidget);
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

    expect(find.text('SENT'), findsNWidgets(2),
        reason: 'an old ACCEPTED request is still waiting for prices');
    expect(find.text('ACCEPTED'), findsNothing);
    for (final label in [
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
    expect(find.byType(RequestDetailScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(PrimaryCta, 'View bids'));
    await tester.pumpAndSettle();
    expect(find.byType(BidListScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(BidListScreen), findsNothing);
    expect(find.byType(RequestDetailScreen), findsOneWidget);

    // Leaving the detail reloads the list behind it.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
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
    await tester.tap(find.widgetWithText(PrimaryCta, 'Rate provider'));
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
    await tester.tap(find.widgetWithText(PrimaryCta, 'Rate provider'));
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
    expect(find.byType(RequestDetailScreen), findsOneWidget);
    expect(find.byType(PrimaryCta), findsNothing);
    await tester.pumpAndSettle();

    expect(find.byType(RatingScreen), findsNothing);
    expect(fake.calls.where((c) => c.contains('/ratings/')), isEmpty);
  });

  testWidgets('the detail view shows the status, facts and a progress timeline',
      (tester) async {
    installFakeApi({
      'GET /requirements/mine': (_) => [
            requirementJson('r1', 'Fan job', 'BID_RECEIVED',
                bids: [bidJson('b1'), bidJson('b2')])
          ],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fan job'));
    await tester.pumpAndSettle();

    expect(find.byType(RequestDetailScreen), findsOneWidget);
    expect(find.text('2 BIDS'), findsWidgets);
    expect(find.text('Bids received'), findsOneWidget);
    expect(find.text('Provider confirmed'), findsOneWidget);
    expect(find.text('Accepted by a provider'), findsNothing,
        reason: 'providers accept by sending a price');
    expect(find.text('BIDS'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a single bid reads 1 BID', (tester) async {
    installFakeApi({
      'GET /requirements/mine': (_) => [
            requirementJson('r1', 'Fan job', 'BID_RECEIVED',
                bids: [bidJson('b1')]),
          ],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('1 BID'), findsOneWidget);
    expect(find.text('1 BIDS'), findsNothing);
  });

  testWidgets("the detail lists each provider's own answer (docx 4.4)",
      (tester) async {
    installFakeApi({
      'GET /requirements/mine': (_) => [
            requirementJson('r1', 'Fan job', 'BID_RECEIVED', bids: [
              bidJson('b1', min: 300, max: 450),
              bidJson('b2', min: 500, max: 900, refinedMin: 550, refinedMax: 700),
            ], providers: [
              targetJson('b1', 'Rajesh Electricals', 'ACCEPTED'),
              targetJson('b2', 'Volt Masters', 'ACCEPTED'),
              targetJson('b3', 'Spark Solutions', 'ACCEPTED'),
              targetJson('b4', 'Anil Thomas', 'REJECTED'),
              targetJson('b5', 'Kochi Plumbing Co', 'SENT'),
            ]),
          ],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fan job'));
    await tester.pumpAndSettle();

    expect(find.text('Providers'), findsOneWidget);
    String badgeFor(String name) => tester
        .widget<TintedBadge>(find.descendant(
            of: find.ancestor(of: find.text(name), matching: find.byType(Row)),
            matching: find.byType(TintedBadge)))
        .label;
    expect(badgeFor('Rajesh Electricals'), 'BID ₹300–₹450');
    expect(badgeFor('Volt Masters'), 'BID ₹550–₹700',
        reason: 'a refined bid shows its latest range');
    expect(badgeFor('Spark Solutions'), 'PENDING',
        reason: 'an accept with no price is still waiting');
    expect(badgeFor('Anil Thomas'), 'REJECTED');
    expect(badgeFor('Kochi Plumbing Co'), 'PENDING');
  });

  testWidgets('once a provider is confirmed the others show as not chosen',
      (tester) async {
    installFakeApi({
      'GET /requirements/mine': (_) => [
            requirementJson('r1', 'Fan job', 'CONFIRMED', bids: [
              bidJson('b1', confirmed: true),
              bidJson('b2'),
            ], providers: [
              targetJson('b1', 'Rajesh Electricals', 'ACCEPTED'),
              targetJson('b2', 'Volt Masters', 'ACCEPTED'),
              targetJson('b3', 'Anil Thomas', 'REJECTED'),
            ]),
          ],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fan job'));
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<TintedBadge>(find.byType(TintedBadge))
        .map((b) => b.label)
        .toList();
    expect(labels, containsAll(['CONFIRMED', 'NOT CHOSEN', 'REJECTED']));
  });

  testWidgets('a request without provider details shows no Providers section',
      (tester) async {
    installFakeApi({
      'GET /requirements/mine': (_) => [requirementJson('r1', 'Fan job', 'SENT')],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fan job'));
    await tester.pumpAndSettle();

    expect(find.text('Providers'), findsNothing);
  });

  testWidgets('a request that ended early shows Sent then how it ended',
      (tester) async {
    installFakeApi({
      'GET /requirements/mine': (_) => [
            requirementJson('r1', 'Old job', 'EXPIRED'),
          ],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Old job'));
    await tester.pumpAndSettle();

    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Bids received'), findsNothing);
    expect(find.byType(PrimaryCta), findsNothing);
  });

  test('requestTimeline marks earlier steps done and later ones to do', () {
    final steps = requestTimeline(RequestStatus.confirmed);
    expect(steps.map((s) => s.label),
        ['Sent', 'Bids received', 'Provider confirmed', 'Job completed']);
    expect(steps.map((s) => s.state), [
      TimelineState.done,
      TimelineState.done,
      TimelineState.current,
      TimelineState.todo,
    ]);
    expect(requestTimeline(RequestStatus.accepted).first.state,
        TimelineState.current,
        reason: 'an old ACCEPTED request is still at Sent');
    expect(requestTimeline(RequestStatus.completed).last.state,
        TimelineState.done);
    expect(requestTimeline(RequestStatus.rejected).last.label, 'Rejected');
    expect(requestTimeline(RequestStatus.cancelled).last.label, 'Cancelled');
  });

  group('openRequestById (notification tap)', () {
    Future<void> pumpOpener(WidgetTester tester, String id) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () => openRequestById(context, id),
                child: const Text('open')),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens the detail of that request', (tester) async {
      installFakeApi({
        'GET /requirements/mine': (_) => [
              requirementJson('r1', 'Other job', 'SENT', title: 'Other'),
              requirementJson('r2', 'Fan rattles', 'BID_RECEIVED',
                  title: 'Fan repair', bids: [bidJson('b1')]),
            ],
      });
      await pumpOpener(tester, 'r2');

      expect(find.byType(RequestDetailScreen), findsOneWidget);
      expect(find.text('Fan repair'), findsOneWidget);
      expect(find.text('View bids'), findsOneWidget);
    });

    testWidgets('says so when the request is no longer there', (tester) async {
      installFakeApi({'GET /requirements/mine': (_) => []});
      await pumpOpener(tester, 'gone');

      expect(find.byType(RequestDetailScreen), findsNothing);
      expect(find.text('This request is no longer available.'), findsOneWidget);
    });

    testWidgets('says so when the requests cannot load', (tester) async {
      installFakeApi(
          {'GET /requirements/mine': (_) => const FakeError(500, 'down')});
      await pumpOpener(tester, 'r1');

      expect(find.byType(RequestDetailScreen), findsNothing);
      expect(find.textContaining('Could not open this request'), findsOneWidget);
    });
  });
}
