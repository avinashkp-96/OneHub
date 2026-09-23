import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/dashboard/dashboard_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  testWidgets('section cards clip their ink ripple to the theme card radius', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.light(), home: const DashboardScreen()),
    );

    final inkWells = tester.widgetList<InkWell>(find.byType(InkWell));
    expect(inkWells, isNotEmpty);
    for (final inkWell in inkWells) {
      expect(
        inkWell.borderRadius,
        BorderRadius.circular(24),
        reason: 'InkWell radius should match OneHubTheme.cardTheme so the ripple '
            'does not poke past the rounded card corners',
      );
    }
  });
}
