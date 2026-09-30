import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/requirements/rating_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.light(),
        home: const RatingScreen(requirementId: 'req-1', providerId: 'prov-1'),
      ),
    );
  }

  testWidgets('shows the heading, 5 stars, and the feedback field label',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Rate this service'), findsOneWidget);
    expect(find.byIcon(OneHubIcons.starOutline), findsNWidgets(5));
    expect(find.textContaining('WRITTEN FEEDBACK'), findsOneWidget);
  });

  testWidgets('the form is a single GlowCard wrapped in PageGlow',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.byType(PageGlow), findsOneWidget);
  });

  testWidgets('tapping a star fills it in and shows its rating label',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(OneHubIcons.starOutline).at(3));
    await tester.pump();

    expect(find.byIcon(OneHubIcons.starFilled), findsNWidgets(4));
    expect(find.text('Great'), findsOneWidget);
  });

  testWidgets('the submit button is the PrimaryCta labeled Submit Rating',
      (tester) async {
    await pumpScreen(tester);

    expect(find.widgetWithText(PrimaryCta, 'Submit Rating'), findsOneWidget);
  });
}
