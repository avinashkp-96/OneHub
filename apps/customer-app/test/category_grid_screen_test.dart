import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/categories/category_grid_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.light(),
        home: const CategoryGridScreen(),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the heading immediately, with the grid loading',
      (tester) async {
    await pumpScreen(tester);

    // The heading renders on the first frame regardless of the category
    // fetch (which has no real backend in tests) — only the grid below it
    // is gated behind the loading state.
    expect(find.text('Browse services'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('the whole screen is wrapped in PageGlow', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
  });
}
