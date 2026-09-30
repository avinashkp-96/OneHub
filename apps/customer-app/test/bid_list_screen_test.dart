import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/requirements/bid_list_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    // Without a tall enough test viewport, ListView's lazy sliver never
    // builds below-the-fold content (same issue documented in
    // dashboard_screen_test.dart and post_requirement_screen_test.dart).
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.light(),
        home: const BidListScreen(requirementId: 'req-1'),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the heading immediately, with the bid list loading',
      (tester) async {
    await pumpScreen(tester);

    // The heading renders on the first frame regardless of the bid fetch
    // (which has no real backend in tests) — only the list below it is
    // gated behind the loading state.
    expect(find.text('Bids received'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
      'the whole screen is wrapped in PageGlow, with no bid tile GlowCards',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    // GlowCard is reserved for the single primary form card per screen — a
    // bid list is a repeated list, not a form, so it should use none.
    expect(find.byType(GlowCard), findsNothing);
  });
}
