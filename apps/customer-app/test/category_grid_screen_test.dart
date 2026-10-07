import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/categories/category_grid_screen.dart';
import 'package:onehub_customer/features/categories/sub_service_list_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.light(), home: const CategoryGridScreen()),
    );
  }

  final categories = [
    {'id': 'c1', 'name': 'Electrician', 'description': 'Wiring, repairs'},
    {'id': 'c2', 'name': 'Plumber'},
  ];

  testWidgets('shows the heading immediately, with the grid loading',
      (tester) async {
    installFakeApi({'GET /categories': (_) => categories});
    await pumpScreen(tester);

    expect(find.text('Browse services'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('is wrapped in PageGlow and lists each category', (tester) async {
    installFakeApi({'GET /categories': (_) => categories});
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.text('Electrician'), findsOneWidget);
    expect(find.text('Wiring, repairs'), findsOneWidget);
    expect(find.text('Plumber'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no categories',
      (tester) async {
    installFakeApi({'GET /categories': (_) => []});
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(
        find.text('No service categories are available yet.'), findsOneWidget);
  });

  testWidgets('shows an error when the categories cannot be loaded',
      (tester) async {
    installFakeApi({'GET /categories': (_) => const FakeError(500, 'down')});
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load categories'), findsOneWidget);
  });

  testWidgets('tapping a category opens its sub-services', (tester) async {
    installFakeApi({
      'GET /categories': (_) => categories,
      'GET /categories/c1/sub-services': (_) => [],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Electrician'));
    await tester.pumpAndSettle();

    expect(find.byType(SubServiceListScreen), findsOneWidget);
  });
}
