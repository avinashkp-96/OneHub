import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester,
      {List<DetailFact> facts = const [],
      List<DetailBadgeRow> badgeRows = const [],
      Widget? action}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RequestDetailScreen(
                  heading: 'Request',
                  description: 'Fix a ceiling fan',
                  statusLabel: '2 BIDS',
                  statusColor: Colors.orange,
                  steps: const [
                    TimelineStep('Sent', TimelineState.done),
                    TimelineStep('Bids received', TimelineState.current),
                    TimelineStep('Confirmed', TimelineState.todo),
                  ],
                  badgeRowsTitle: 'Providers',
                  badgeRows: badgeRows,
                  facts: facts,
                  action: action,
                ),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows heading, description, status and every timeline step',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Request'), findsOneWidget);
    expect(find.text('Fix a ceiling fan'), findsOneWidget);
    expect(find.text('2 BIDS'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    for (final s in ['Sent', 'Bids received', 'Confirmed']) {
      expect(find.text(s), findsOneWidget);
    }
    // One connector line between each pair of steps, none after the last.
    expect(find.byKey(const Key('timeline-line')), findsNWidgets(2));
  });

  testWidgets('omits Details, badge rows and the action when none are given',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Details'), findsNothing);
    expect(find.text('Providers'), findsNothing);
    expect(find.byType(PrimaryCta), findsNothing);
  });

  testWidgets('shows the badge rows under their title', (tester) async {
    await pumpScreen(tester, badgeRows: const [
      DetailBadgeRow('Rajesh Electricals', 'ACCEPTED', Colors.blue),
      DetailBadgeRow('Kochi Plumbing Co', 'PENDING', Colors.grey),
    ]);

    expect(find.text('Providers'), findsOneWidget);
    expect(find.text('Rajesh Electricals'), findsOneWidget);
    expect(find.text('Kochi Plumbing Co'), findsOneWidget);
    final badges = tester.widgetList<TintedBadge>(find.byType(TintedBadge));
    expect(
        badges.map((b) => b.label), containsAll(['ACCEPTED', 'PENDING']));
  });

  test('Requirement parses each targeted provider and its answer', () {
    final r = Requirement.fromJson({
      'id': 'r1',
      'subServiceId': 's1',
      'description': 'Fix fan',
      'photoUrls': [],
      'status': 'ACCEPTED',
      'bids': [],
      'targetedProviders': [
        {'providerId': 'p1', 'providerName': 'Rajesh Electricals', 'status': 'ACCEPTED'},
        {'providerId': 'p2', 'providerName': 'Anil Thomas', 'status': 'REJECTED'},
        {'providerId': 'p3', 'status': 'SENT'}, // no name: provider side, skipped
      ],
    });

    expect(r.targetedProviders.map((t) => (t.providerName, t.status)), [
      ('Rajesh Electricals', RequestStatus.accepted),
      ('Anil Thomas', RequestStatus.rejected),
    ]);
  });

  test('Requirement without targeted providers has an empty list', () {
    final r = Requirement.fromJson({
      'id': 'r1',
      'subServiceId': 's1',
      'description': 'Fix fan',
      'status': 'SENT',
    });
    expect(r.targetedProviders, isEmpty);
  });

  testWidgets('shows facts and the supplied action', (tester) async {
    var pressed = false;
    await pumpScreen(
      tester,
      facts: const [DetailFact('Photos', '2'), DetailFact('Bids', '3')],
      action: PrimaryCta(
          onPressed: () => pressed = true, child: const Text('View bids')),
    );

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('PHOTOS'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('View bids'));
    expect(pressed, isTrue);
  });

  testWidgets('the back button returns to the previous screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(RequestDetailScreen), findsNothing);
  });
}
