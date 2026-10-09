import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_provider/features/dashboard/dashboard_screen.dart';
import 'package:onehub_provider/features/earnings/earnings_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpEarnings(WidgetTester tester) async {
    tallView(tester);
    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.dark(), home: const EarningsScreen()),
    );
  }

  testWidgets('shows the heading, wallet balance and plan', (tester) async {
    await pumpEarnings(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('WALLET BALANCE'), findsOneWidget);
    expect(find.text(dummyWalletBalance), findsOneWidget);
    expect(find.text(dummyPlan), findsOneWidget);
    expect(find.text(dummyRenewal), findsOneWidget);
  });

  testWidgets('shows earned today, this week and this month', (tester) async {
    await pumpEarnings(tester);

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text(dummyEarnedToday), findsOneWidget);
    expect(find.text('THIS WEEK'), findsOneWidget);
    expect(find.text('₹6,420'), findsOneWidget);
    expect(find.text('THIS MONTH'), findsOneWidget);
    expect(find.text('₹21,300'), findsOneWidget);
  });

  testWidgets('lists recent activity with signed amounts', (tester) async {
    await pumpEarnings(tester);

    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Job completed'), findsNWidgets(2));
    expect(find.text('Contact unlock fee'), findsOneWidget);
    expect(find.text('Pro plan'), findsOneWidget);
    expect(find.text('+₹1,200'), findsOneWidget);
    expect(find.text('−₹50'), findsOneWidget);
    expect(find.text("Payouts and card payments aren't set up yet."),
        findsOneWidget);
  });

  testWidgets('the back button returns to the previous screen', (tester) async {
    tallView(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EarningsScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(EarningsScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(EarningsScreen), findsNothing);
  });

  testWidgets('the dashboard wallet card opens the earnings screen',
      (tester) async {
    tallView(tester);
    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.dark(), home: const DashboardScreen()),
    );

    await tester.tap(find.text('Wallet balance'));
    await tester.pumpAndSettle();

    expect(find.byType(EarningsScreen), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
  });
}
