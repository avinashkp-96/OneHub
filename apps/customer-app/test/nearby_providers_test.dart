import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/dashboard/dashboard_screen.dart';
import 'package:onehub_customer/features/profile/profile_state.dart';
import 'package:onehub_customer/features/providers/nearby_providers_screen.dart';
import 'package:onehub_customer/features/requirements/post_requirement_screen.dart';
import 'package:onehub_customer/features/search/search_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  const edappally =
      SavedLocation(city: 'Edappally', latitude: 10.0261, longitude: 76.3125);
  tearDown(() => customerLocation.value = null);

  Map<String, Object?> provider(String id, String name, double km) => {
        'id': id,
        'name': name,
        'averageRating': 4.5,
        'ratingCount': 3,
        'certified': false,
        'categories': ['Electrician'],
        'services': [
          {'id': 's-$id', 'name': 'Fan Installation'}
        ],
        'startingPrice': 250,
        'distanceKm': km,
      };
  final four = [
    provider('p1', 'Kochi Plumbing Co', 3.4),
    provider('p2', 'Rajesh Electricals', 6.7),
    provider('p3', 'Volt Masters', 8.1),
    provider('p4', 'Far Away Fixers', 20),
  ];

  late List<Uri> searches;
  FakeApi install({Object? Function()? answer}) {
    searches = [];
    return installFakeApi({
      'GET /categories': (_) => [],
      'GET /requirements/mine': (_) => [],
      'GET /search': (r) {
        searches.add(r.url);
        return answer != null ? answer() : {'services': [], 'providers': four};
      },
      'GET /users/me/addresses': (_) => [],
      'GET /providers': (_) => [
            {'id': 'p2', 'businessName': 'Rajesh Electricals', 'averageRating': 4.5, 'certified': false},
            {'id': 'p9', 'businessName': 'Someone Else', 'averageRating': 4.0, 'certified': false},
          ],
    });
  }

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(theme: OneHubTheme.dark(), home: const DashboardScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('Home shows one Nearby providers card naming the area',
      (tester) async {
    install();
    await pumpHome(tester);

    expect(find.text('Find providers near you'), findsOneWidget);
    expect(find.text('Rated providers for every service'), findsOneWidget);
    expect(find.byType(ProviderHitCard), findsNothing);
    expect(searches, isEmpty, reason: 'Home loads no provider list');

    customerLocation.value = edappally;
    await tester.pump();
    expect(find.text('Rated providers around Edappally'), findsOneWidget);
  });

  testWidgets('the card and See all both open the list, nearest first',
      (tester) async {
    customerLocation.value = edappally;
    install();
    await pumpHome(tester);

    for (final open in [
      find.byKey(const Key('nearby-providers-card')),
      find.text('See all').last,
    ]) {
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(NearbyProvidersScreen), findsOneWidget);
      expect(searches.last.queryParameters,
          {'sort': 'distance', 'latitude': '10.0261', 'longitude': '76.3125'});
      expect(find.text('Nearest first, from Edappally.'), findsOneWidget);
      expect(find.byType(ProviderHitCard), findsNWidgets(4));
      expect(find.text('Electrician · 3.4 km away'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('without an address the list is best rated first and says why',
      (tester) async {
    install();
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(), home: const NearbyProvidersScreen()));
    await tester.pumpAndSettle();

    expect(searches.single.query, isEmpty);
    expect(
        find.text('Best rated first. Set your address on Home to see who is nearest.'),
        findsOneWidget);
  });

  testWidgets('a provider in the list opens a request with them ticked',
      (tester) async {
    customerLocation.value = edappally;
    install();
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(), home: const NearbyProvidersScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rajesh Electricals'));
    await tester.pumpAndSettle();

    final screen = tester.widget<PostRequirementScreen>(find.byType(PostRequirementScreen));
    expect(screen.subServiceId, 's-p2');
    expect(screen.preselectedProviderId, 'p2');
    expect(find.byIcon(OneHubIcons.confirmed), findsOneWidget,
        reason: 'Rajesh is ticked, Someone Else is not');
  });

  testWidgets('the full list shows its own empty and error states',
      (tester) async {
    install(answer: () => {'services': [], 'providers': []});
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(), home: const NearbyProvidersScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No providers yet.'), findsOneWidget);

    install(answer: () => const FakeError(500, 'down'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(), home: const NearbyProvidersScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load providers'), findsOneWidget);
  });
}
