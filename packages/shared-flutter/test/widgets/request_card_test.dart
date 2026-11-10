import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  final now = DateTime(2026, 10, 30, 12);

  Future<void> pumpCard(WidgetTester tester, RequestCard card) async {
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ));
  }

  group('postedLabel', () {
    test('reads naturally for recent and older posts', () {
      expect(postedLabel(now, now), 'Posted just now');
      expect(postedLabel(now.subtract(const Duration(minutes: 5)), now),
          'Posted 5 min ago');
      expect(postedLabel(now.subtract(const Duration(hours: 30)), now),
          'Posted yesterday');
      expect(postedLabel(now.subtract(const Duration(days: 2)), now),
          'Posted 2 days ago');
      expect(postedLabel(DateTime(2026, 10, 12), now), 'Posted on 12 Oct');
    });
  });

  testWidgets('shows the status, posted time, title and description',
      (tester) async {
    await pumpCard(
        tester,
        RequestCard(
          statusLabel: 'NEW',
          statusColor: Colors.orange,
          postedAt: now.subtract(const Duration(days: 2)),
          now: now,
          title: 'Fan repair',
          description: 'The fan rattles at high speed',
        ));

    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('Posted 2 days ago'), findsOneWidget);
    expect(find.text('Fan repair'), findsOneWidget);
    expect(find.text('The fan rattles at high speed'), findsOneWidget);
    // A dark surface with the brand blue fading out from the top-left.
    final card = tester.widget<Container>(find.byKey(const Key('request-card')));
    final gradient =
        (card.decoration as BoxDecoration).gradient as LinearGradient;
    expect(gradient.colors.last, OneHubColors.navBarFillDark);
    expect(gradient.colors.first, isNot(OneHubColors.navBarFillDark));
    expect(gradient.colors.first.b, greaterThan(gradient.colors.last.b));
    expect(gradient.begin, Alignment.topLeft);
  });

  testWidgets('hides the posted time, description and facts when absent',
      (tester) async {
    await pumpCard(
        tester,
        const RequestCard(
            statusLabel: 'SENT', statusColor: Colors.blue, title: 'Fan'));

    expect(find.textContaining('Posted'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('lays facts out two to a row under a divider', (tester) async {
    await pumpCard(
        tester,
        const RequestCard(
          statusLabel: 'NEW',
          statusColor: Colors.orange,
          title: 'Fan repair',
          facts: [
            RequestCardFact('CUSTOMER', 'Meera Nair'),
            RequestCardFact('LOCATION', 'Kochi · 6.7 km'),
            RequestCardFact('TYPICAL PRICE', '₹250 – ₹450'),
          ],
        ));

    expect(find.byType(Divider), findsOneWidget);
    final customer = tester.getRect(find.text('CUSTOMER'));
    final location = tester.getRect(find.text('LOCATION'));
    final price = tester.getRect(find.text('TYPICAL PRICE'));
    expect(location.top, customer.top);
    expect(location.left, greaterThan(customer.left));
    expect(price.top, greaterThan(customer.top));
    expect(price.left, customer.left);
  });

  testWidgets('shows the footer and calls onTap', (tester) async {
    var taps = 0;
    await pumpCard(
        tester,
        RequestCard(
          statusLabel: 'SENT',
          statusColor: Colors.blue,
          title: 'Fan repair',
          footer: const Text('footer'),
          onTap: () => taps++,
        ));

    expect(find.text('footer'), findsOneWidget);
    await tester.tap(find.text('Fan repair'));
    expect(taps, 1);
  });

  testWidgets('uses the compact sizes', (tester) async {
    await pumpCard(
        tester,
        RequestCard(
          statusLabel: 'NEW',
          statusColor: Colors.orange,
          postedAt: now,
          now: now,
          title: 'Fan repair',
          description: 'The fan rattles',
          facts: const [RequestCardFact('CUSTOMER', 'Meera Nair')],
        ));

    double size(String text) =>
        tester.widget<Text>(find.text(text)).style!.fontSize!;
    expect(size('Fan repair'), 18);
    expect(size('The fan rattles'), 13);
    expect(size('Meera Nair'), 14);
    expect(size('Posted just now'), 11);

    final card = tester.getRect(find.byKey(const Key('request-card')));
    final status = tester.getRect(find.text('NEW'));
    expect(status.left - card.left, lessThan(30),
        reason: '14px padding plus the pill inset');
  });
}
