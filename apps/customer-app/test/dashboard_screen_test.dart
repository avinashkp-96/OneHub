import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/dashboard/dashboard_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  testWidgets('section cards clip their ink ripple to the theme card radius',
      (tester) async {
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
}
