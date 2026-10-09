import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_provider/features/certification/certification_screen.dart';
import 'package:onehub_provider/features/dashboard/dashboard_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(theme: OneHubTheme.dark(), home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the heading and a progress card with the done count',
      (tester) async {
    await pumpScreen(tester, const CertificationScreen());

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Get certified'), findsOneWidget);
    expect(find.text('Your progress'), findsOneWidget);
    expect(find.text('3 of 5 steps'), findsOneWidget);
  });

  testWidgets('lists every step with its description', (tester) async {
    await pumpScreen(tester, const CertificationScreen());

    for (final step in certificationSteps) {
      expect(find.text(step.title), findsOneWidget, reason: step.title);
      expect(find.text(step.description), findsOneWidget, reason: step.title);
    }
  });

  testWidgets('marks each step done, in progress or to do', (tester) async {
    await pumpScreen(tester, const CertificationScreen());

    expect(find.text('DONE'), findsNWidgets(3));
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('TO DO'), findsOneWidget);
    expect(find.byIcon(OneHubIcons.successCheck), findsNWidgets(3),
        reason: 'done steps show a check');
    expect(find.text('4'), findsOneWidget,
        reason: 'unfinished steps show their number');
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('applying is disabled until every step is done', (tester) async {
    await pumpScreen(tester, const CertificationScreen());

    final apply = tester.widget<PrimaryCta>(
        find.widgetWithText(PrimaryCta, 'Apply for certification'));
    expect(apply.onPressed, isNull);
    expect(find.text('Finish all 5 steps to apply.'), findsOneWidget);
  });

  testWidgets('the back button returns to the previous screen', (tester) async {
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CertificationScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(CertificationScreen), findsNothing);
  });

  testWidgets(
      'the dashboard card shows the same progress and opens this screen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(theme: OneHubTheme.dark(), home: const DashboardScreen()));

    expect(find.text('3 of 5 steps'), findsOneWidget);

    await tester.tap(find.text('Get certified'));
    await tester.pumpAndSettle();

    expect(find.byType(CertificationScreen), findsOneWidget);
  });
}
