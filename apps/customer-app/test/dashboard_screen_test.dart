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
      'the hero CTA\'s icon is two overlapped chevrons ("slide" affordance), not a single arrow',
      (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.light(), home: const DashboardScreen()),
    );

    final chevrons = tester
        .widgetList<Icon>(find.byIcon(OneHubIcons.chevronRight))
        .where((icon) => icon.color == OneHubColors.surfaceDark);
    expect(chevrons, hasLength(2));

    // The pair is laid out in a fixed-size Stack (not Row + Transform), so
    // its bounding box matches what's actually painted and Center's
    // alignment isn't thrown off by an oversized, invisible layout width.
    final iconBox = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((box) => box.width == 20 && box.height == 14);
    expect(iconBox, hasLength(1));
  });

  testWidgets('the hero CTA is full width, bordered, and centers its label',
      (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.dark(), home: const DashboardScreen()),
    );

    final ctaContainer = tester.widget<Container>(
      find
          .ancestor(
              of: find.text('Post requirement'),
              matching: find.byType(Container))
          .first,
    );
    expect(ctaContainer.constraints?.maxWidth, double.infinity,
        reason:
            'the button should stretch to the card width, not just wrap its content');
    final decoration = ctaContainer.decoration as BoxDecoration;
    expect(decoration.border, isNotNull,
        reason: 'the button needs a visible border per the reference');

    // The label sits inside an Expanded + Center, not directly next to the
    // icon circle, so it reads as centered in the button's remaining space.
    expect(
      find.ancestor(
          of: find.text('Post requirement'), matching: find.byType(Center)),
      findsWidgets,
    );
  });

  testWidgets(
      'the bottom nav has 4 items (Home, Requests, Category, Profile) with Home selected',
      (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.dark(), home: const DashboardScreen()),
    );

    final navBar = tester.widget<CurvedNavBar>(find.byType(CurvedNavBar));
    expect(navBar.items.map((i) => i.label),
        ['Home', 'Requests', 'Category', 'Profile']);
    expect(navBar.selectedIndex, 0);
  });
}
