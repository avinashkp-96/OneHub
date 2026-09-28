import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/requirements/post_requirement_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    // Without a tall enough test viewport, ListView's lazy sliver never
    // builds the below-the-fold PrimaryCta at the bottom of the form (same
    // issue documented in dashboard_screen_test.dart).
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.light(),
        home: const PostRequirementScreen(subServiceId: 'sub-1'),
      ),
    );
    // The form (description/date) renders on the very first frame — only
    // the provider list below it waits on the (backend-less, in tests)
    // network fetch, so a single pump is enough for these assertions.
    await tester.pump();
  }

  testWidgets('shows the form heading, description field and date field labels',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Tell us what you need'), findsOneWidget);
    expect(find.textContaining('WHAT DO YOU NEED DONE?'), findsOneWidget);
    expect(find.textContaining('PREFERRED DATE/TIME'), findsOneWidget);
    expect(find.text('Any time works'), findsOneWidget);
  });

  testWidgets('the form card is a single GlowCard, not repeated per field',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(GlowCard), findsOneWidget);
  });

  testWidgets('the whole screen is wrapped in PageGlow', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
  });

  testWidgets('the send button is the PrimaryCta labeled Send Request',
      (tester) async {
    await pumpScreen(tester);

    expect(find.widgetWithText(PrimaryCta, 'Send Request'), findsOneWidget);
  });
}
