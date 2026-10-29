import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onehub_customer/features/requirements/post_requirement_screen.dart';
import 'package:onehub_customer/features/search/search_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  setUp(() => recentSearches.value = const []);

  Map<String, dynamic> results() => {
        'services': [
          {
            'id': 's1',
            'name': 'Switchboard Repair',
            'categoryName': 'Electrician',
            'suggestedMinPrice': 200,
            'suggestedMaxPrice': 500,
          },
          {
            'id': 's9',
            'name': 'Inspection',
            'categoryName': 'Electrician',
            'suggestedMinPrice': null,
            'suggestedMaxPrice': null,
          },
        ],
        'providers': [
          {
            'id': 'p1',
            'name': 'Rajesh Electricals',
            'averageRating': 4.6,
            'ratingCount': 12,
            'certified': true,
            'categories': ['Electrician'],
            'services': [
              {'id': 's1', 'name': 'Switchboard Repair'},
              {'id': 's2', 'name': 'Fan Installation'},
            ],
            'startingPrice': 200,
          },
          {
            'id': 'p2',
            'name': 'Volt Masters',
            'averageRating': 0,
            'ratingCount': 0,
            'certified': false,
            'categories': ['Electrician'],
            'services': [
              {'id': 's9', 'name': 'Inspection'}
            ],
            'startingPrice': null,
          },
        ],
      };

  late FakeApi fake;
  late List<Uri> searches;

  Future<void> pumpScreen(WidgetTester tester,
      {Object? Function(http.Request)? onSearch}) async {
    searches = [];
    fake = installFakeApi({
      'GET /search': (r) {
        searches.add(r.url);
        return onSearch != null ? onSearch(r) : results();
      },
      'GET /search/suggest': (r) =>
          r.url.queryParameters['q'] == 'sw' ? ['Switchboard Repair'] : [],
      'GET /categories': (_) => [
            {'id': 'c1', 'name': 'Electrician'},
            {'id': 'c2', 'name': 'Plumber'},
          ],
      'GET /providers': (_) => [],
    });
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(theme: OneHubTheme.dark(), home: const SearchScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> searchFor(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('search-field')), text);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
  }

  testWidgets('starts with a hint and the page name in the top bar',
      (tester) async {
    await pumpScreen(tester);

    expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Search')),
        findsOneWidget);
    expect(find.textContaining('Search by service'), findsOneWidget);
    expect(searches, isEmpty);
  });

  testWidgets('submitting shows services and providers', (tester) async {
    await pumpScreen(tester);

    await searchFor(tester, 'repair');

    expect(searches.single.queryParameters, {'q': 'repair'});
    expect(find.text('Services'), findsOneWidget);
    expect(find.text('TYPICALLY ₹200–₹500'), findsOneWidget);
    expect(find.text('Providers'), findsOneWidget);
    expect(find.text('Rajesh Electricals'), findsOneWidget);
    expect(find.text('4.6★ (12)'), findsOneWidget);
    expect(find.text('CERTIFIED'), findsOneWidget);
    expect(find.text('FROM ₹200'), findsOneWidget);
    expect(find.text('Switchboard Repair · Fan Installation'), findsOneWidget);
    expect(find.text('New'), findsOneWidget,
        reason: 'a provider with no ratings yet');
  });

  testWidgets('suggestions appear after two letters and run a search',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byKey(const Key('search-field')), 's');
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.calls.where((c) => c == 'GET /search/suggest'), isEmpty);

    await tester.enterText(find.byKey(const Key('search-field')), 'sw');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Switchboard Repair'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'Switchboard Repair'));
    await tester.pumpAndSettle();
    expect(searches.single.queryParameters['q'], 'Switchboard Repair');
  });

  testWidgets('remembers recent searches, newest first, and reruns them',
      (tester) async {
    await pumpScreen(tester);
    await searchFor(tester, 'fan');
    await searchFor(tester, 'tap');
    await searchFor(tester, 'FAN');

    expect(recentSearches.value, ['FAN', 'tap'],
        reason: 'a repeat moves to the top instead of duplicating');

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'tap'));
    await tester.pumpAndSettle();
    expect(searches.last.queryParameters['q'], 'tap');
  });

  test('keeps at most five recent searches', () {
    for (final q in ['a', 'b', 'c', 'd', 'e', 'f', ' ']) {
      rememberSearch(q);
    }
    expect(recentSearches.value, ['f', 'e', 'd', 'c', 'b']);
  });

  testWidgets('Clear in Recent searches empties the list', (tester) async {
    recentSearches.value = ['fan'];
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('filters are sent with the search and shown as chips',
      (tester) async {
    await pumpScreen(tester);
    await searchFor(tester, 'repair');

    await tester.tap(find.byKey(const Key('filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Plumber'));
    await tester.tap(find.widgetWithText(ChoiceChip, '4★ and up'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Up to ₹500'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Lowest price'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(searches.last.queryParameters, {
      'q': 'repair',
      'categoryId': 'c2',
      'minRating': '4.0',
      'maxPrice': '500',
      'sort': 'price',
    });
    for (final chip in ['Plumber', '4★ and up', 'Up to ₹500', 'Lowest price first']) {
      expect(find.widgetWithText(TintedBadge, chip), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(searches.last.queryParameters, {'q': 'repair'});
  });

  testWidgets('shows the empty state when nothing matches', (tester) async {
    await pumpScreen(tester,
        onSearch: (_) => {'services': [], 'providers': []});

    await searchFor(tester, 'helicopter');

    expect(find.text('No providers found nearby.'), findsOneWidget);
    expect(find.textContaining('remove some filters'), findsOneWidget);
  });

  testWidgets('says so when the search fails', (tester) async {
    await pumpScreen(tester, onSearch: (_) => const FakeError(500, 'down'));

    await searchFor(tester, 'fan');

    expect(find.textContaining('Search failed'), findsOneWidget);
  });

  testWidgets('tapping a service or provider opens Post a Requirement for it',
      (tester) async {
    await pumpScreen(tester);
    await searchFor(tester, 'repair');

    await tester.tap(find.text('Inspection').first);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<PostRequirementScreen>(find.byType(PostRequirementScreen))
            .subServiceId,
        's9');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rajesh Electricals'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<PostRequirementScreen>(find.byType(PostRequirementScreen))
            .subServiceId,
        's1',
        reason: "the provider's first matching service");
  });
}
