import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/dashboard/dashboard_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  testWidgets('section cards clip their ink ripple to the theme card radius',
      (tester) async {
    // The dashboard is much taller than the default test viewport now (header,
    // search, hero, services, requests, providers, promo) — without a tall
    // enough surface, ListView's lazy sliver never builds the below-the-fold
    // cards (e.g. the Nearby Providers prompt), and the InkWell search below
    // silently comes back empty instead of actually failing on a bad radius.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.light(), home: const DashboardScreen()),
    );

    // Scoped to the section-card InkWells specifically — PrimaryCta (the
    // "Post a Requirement" button) has its own InkWell with the CTA button's
    // radius instead, which is a different, intentionally distinct shape.
    final inkWells = tester.widgetList<InkWell>(
      find.descendant(of: find.byType(Card), matching: find.byType(InkWell)),
    );
    expect(inkWells, isNotEmpty);
    for (final inkWell in inkWells) {
      expect(
        inkWell.borderRadius,
        BorderRadius.circular(OneHubTheme.radiusFormCard),
        reason:
            'InkWell radius should match OneHubTheme.cardTheme so the ripple '
            'does not poke past the rounded card corners — this asserts against '
            'the theme constant, not a hardcoded number, precisely so it cannot '
            'silently drift out of sync with the theme again like it did across '
            'the last two retheme rounds',
      );
    }
  });

  testWidgets(
      'Services grid shows the 4 dummy categories with their pro counts',
      (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.light(), home: const DashboardScreen()),
    );

    // Explicit dummy data per a reference screenshot ("use dummy data for
    // now") — ServiceCategory has no "available pros" field at all, so this
    // exact stat can't come from the real /categories endpoint yet.
    expect(find.text('Electrician'), findsOneWidget);
    expect(find.text('18 available pros'), findsOneWidget);
    expect(find.text('Plumber'), findsOneWidget);
    expect(find.text('24 available pros'), findsOneWidget);
    expect(find.text('Painter'), findsOneWidget);
    expect(find.text('31 available pros'), findsOneWidget);
    expect(find.text('Carpenter'), findsOneWidget);
    expect(find.text('12 available pros'), findsOneWidget);
  });

  testWidgets(
      'the Scaffold extends its body behind CurvedNavBar so the blur has real content to blur',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.dark(), home: const DashboardScreen()),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(
      scaffold.extendBody,
      isTrue,
      reason:
          'without this, Scaffold reserves body height above the bottom nav bar, so '
          "there's nothing but the flat scaffoldBackgroundColor behind CurvedNavBar's "
          'translucent/wavy gaps for its BackdropFilter to actually blur',
    );
  });
}
