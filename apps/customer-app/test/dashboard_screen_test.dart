import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/categories/sub_service_list_screen.dart';
import 'package:onehub_customer/features/dashboard/dashboard_screen.dart';
import 'package:onehub_customer/features/profile/profile_state.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  group('greeting', () {
    Future<FakeApi> pumpWith(
        WidgetTester tester, Object? Function(dynamic) me) async {
      customerProfile.value = null;
      addTearDown(() => customerProfile.value = null);
      final fake = installFakeApi({
        'GET /requirements/mine': (_) => [],
        'GET /users/me': me,
      });
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: OneHubTheme.light(), home: const DashboardScreen()),
      );
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('greets the signed-in customer by first name', (tester) async {
      final fake = await pumpWith(tester,
          (_) => {'fullName': 'Anil Kumar', 'mobile': '9000000009'});

      expect(fake.calls, contains('GET /users/me'));
      expect(find.text('What needs fixing today, Anil?'), findsOneWidget);
      expect(find.textContaining('Meera'), findsNothing);
    });

    testWidgets('leaves the name out when the profile cannot load',
        (tester) async {
      await pumpWith(tester, (_) => const FakeError(500));

      expect(find.text('What needs fixing today?'), findsOneWidget);
    });
  });

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

  group('Expert services grid', () {
    Map<String, dynamic> cat(String id, String name, int count) =>
        {'id': id, 'name': name, 'active': true, 'providerCount': count};

    Future<FakeApi> pumpWith(WidgetTester tester, Object? categories) async {
      final fake = installFakeApi({
        'GET /requirements/mine': (_) => [],
        'GET /categories': (_) => categories,
        'GET /categories/cat-p/sub-services': (_) => [],
      });
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: OneHubTheme.light(), home: const DashboardScreen()),
      );
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('shows the four categories with the most providers',
        (tester) async {
      await pumpWith(tester, [
        cat('cat-a', 'AC Repair', 0),
        cat('cat-c', 'Carpenter', 1),
        cat('cat-e', 'Electrician', 2),
        cat('cat-p', 'Plumber', 12),
        cat('cat-x', 'Painter', 2),
      ]);

      expect(find.text('Plumber'), findsOneWidget);
      expect(find.text('12 pros'), findsOneWidget);
      expect(find.text('Electrician'), findsOneWidget);
      expect(find.text('Painter'), findsOneWidget);
      expect(find.text('2 pros'), findsNWidgets(2));
      expect(find.text('Carpenter'), findsOneWidget);
      expect(find.text('1 pro'), findsOneWidget);
      expect(find.text('AC Repair'), findsNothing,
          reason: 'the fewest providers, so the fifth and left out');
      expect(find.textContaining('available pros'), findsNothing);
    });

    testWidgets('tapping a category opens its services', (tester) async {
      final fake = await pumpWith(tester, [cat('cat-p', 'Plumber', 3)]);

      await tester.tap(find.text('Plumber'));
      await tester.pumpAndSettle();

      expect(find.byType(SubServiceListScreen), findsOneWidget);
      expect(fake.calls, contains('GET /categories/cat-p/sub-services'));
    });

    testWidgets('shows nothing when the categories cannot load',
        (tester) async {
      await pumpWith(tester, const FakeError(500));

      expect(find.text('Expert services'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^(\d+ pros?|No pros yet)$')),
          findsNothing);
    });
  });

  test('topCategories ranks by provider count, then name', () {
    const all = [
      ServiceCategory(id: '1', name: 'B', providerCount: 2),
      ServiceCategory(id: '2', name: 'A', providerCount: 2),
      ServiceCategory(id: '3', name: 'C', providerCount: 5),
    ];
    expect(topCategories(all).map((c) => c.name), ['C', 'A', 'B']);
  });

  test('proCountLabel', () {
    expect(proCountLabel(0), 'No pros yet');
    expect(proCountLabel(1), '1 pro');
    expect(proCountLabel(7), '7 pros');
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
}
