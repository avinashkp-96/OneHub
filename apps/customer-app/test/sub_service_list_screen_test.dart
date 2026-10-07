import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/categories/sub_service_list_screen.dart';
import 'package:onehub_customer/features/requirements/post_requirement_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  const category = ServiceCategory(id: 'c1', name: 'Electrician');

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
          theme: OneHubTheme.light(),
          home: const SubServiceListScreen(category: category)),
    );
  }

  testWidgets('shows the category name as the heading, with the list loading',
      (tester) async {
    installFakeApi({'GET /categories/c1/sub-services': (_) => []});
    await pumpScreen(tester);

    expect(find.text('Electrician'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('lists sub-services, with a price badge only when a range exists',
      (tester) async {
    installFakeApi({
      'GET /categories/c1/sub-services': (_) => [
            {
              'id': 's1',
              'categoryId': 'c1',
              'name': 'Wiring repair',
              'suggestedMinPrice': 500,
              'suggestedMaxPrice': 1200
            },
            {
              'id': 's2',
              'categoryId': 'c1',
              'name': 'Switchboard installation'
            },
          ],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.text('Wiring repair'), findsOneWidget);
    expect(find.text('TYPICALLY ₹500–₹1200'), findsOneWidget);
    expect(find.text('Switchboard installation'), findsOneWidget);
    expect(find.textContaining('TYPICALLY'), findsOneWidget);
  });

  testWidgets('shows an empty state when the category has no services',
      (tester) async {
    installFakeApi({'GET /categories/c1/sub-services': (_) => []});
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('No services listed under this category yet.'),
        findsOneWidget);
  });

  testWidgets('shows an error when the services cannot be loaded',
      (tester) async {
    installFakeApi({
      'GET /categories/c1/sub-services': (_) => const FakeError(500, 'down')
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load services'), findsOneWidget);
  });

  testWidgets('tapping a service opens the post requirement screen for it',
      (tester) async {
    final fake = installFakeApi({
      'GET /categories/c1/sub-services': (_) => [
            {'id': 's1', 'categoryId': 'c1', 'name': 'Wiring repair'},
          ],
      'GET /providers': (_) => [],
    });
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wiring repair'));
    await tester.pumpAndSettle();

    expect(find.byType(PostRequirementScreen), findsOneWidget);
    expect(fake.calls, contains('GET /providers'));
  });
}
