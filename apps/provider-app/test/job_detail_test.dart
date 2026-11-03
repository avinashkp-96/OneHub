import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_provider/features/requirements/job_detail.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  group('preferredDateLabel', () {
    final now = DateTime(2026, 11, 3, 22);

    test('is null with no date', () {
      expect(preferredDateLabel(null, now), isNull);
    });

    test('says Today and Tomorrow by calendar day, not 24 hours', () {
      expect(preferredDateLabel(DateTime(2026, 11, 3, 8), now), 'Today');
      expect(preferredDateLabel(DateTime(2026, 11, 4, 1), now), 'Tomorrow');
    });

    test('shows the day and month otherwise, past dates included', () {
      expect(preferredDateLabel(DateTime(2026, 11, 9), now), '9 Nov');
      expect(preferredDateLabel(DateTime(2026, 11, 1), now), '1 Nov');
    });
  });

  Requirement withBid(Map<String, dynamic> bid) => Requirement.fromJson({
        'id': 'r',
        'subServiceId': 's',
        'description': 'd',
        'status': 'BID_RECEIVED',
        'bids': [
          {
            'id': 'b',
            'providerId': 'p',
            'contactUnlocked': false,
            'confirmed': false,
            ...bid,
          }
        ],
      });

  test('bidRangeLabel uses the refined range once there is one', () {
    expect(
        bidRangeLabel(withBid({'initialMinPrice': 350, 'initialMaxPrice': 600})),
        '₹350 – ₹600');
    expect(
        bidRangeLabel(withBid({
          'initialMinPrice': 350,
          'initialMaxPrice': 600,
          'refinedMinPrice': 400,
          'refinedMaxPrice': 450,
        })),
        '₹400 – ₹450');
  });

  test('bidRangeLabel is null before a price is sent', () {
    expect(
        bidRangeLabel(Requirement.fromJson({
          'id': 'r',
          'subServiceId': 's',
          'description': 'd',
          'status': 'SENT',
        })),
        isNull);
  });

  List<(String, TimelineState)> steps(IncomingStage stage) =>
      [for (final s in jobTimeline(stage)) (s.label, s.state)];

  test('jobTimeline follows each stage', () {
    expect(steps(IncomingStage.newRequest), [
      ('Send your price', TimelineState.current),
      ('Customer chooses a provider', TimelineState.todo),
      ('Job in progress', TimelineState.todo),
      ('Completed', TimelineState.todo),
    ]);
    expect(steps(IncomingStage.bidSent).take(2), [
      ('Send your price', TimelineState.done),
      ('Customer chooses a provider', TimelineState.current),
    ]);
    expect(steps(IncomingStage.selected)[2],
        ('Job in progress', TimelineState.current));
    expect(steps(IncomingStage.completed).every((s) => s.$2 == TimelineState.done),
        isTrue);
    expect(steps(IncomingStage.notSelected), [
      ('Send your price', TimelineState.done),
      ('Customer chooses a provider', TimelineState.done),
      ('Not selected', TimelineState.current),
    ]);
    expect(steps(IncomingStage.closed),
        [('Closed to new prices', TimelineState.current)]);
  });

  testWidgets('every stage has a label and a colour', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(),
        home: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        })));

    for (final stage in IncomingStage.values) {
      expect(incomingStageLabel(stage), isNotEmpty);
      expect(incomingStageColor(context, stage), isA<Color>());
    }
    expect(incomingStageLabel(IncomingStage.bidSent), 'BID SENT');
  });
}
