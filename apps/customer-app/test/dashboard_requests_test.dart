import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onehub_customer/features/categories/category_grid_screen.dart';
import 'package:onehub_customer/features/dashboard/dashboard_screen.dart';
import 'package:onehub_customer/features/profile/profile_screen.dart';
import 'package:onehub_customer/features/requirements/my_requests_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester,
      Map<String, Object? Function(http.Request)> routes) async {
    installFakeApi({
      'GET /categories': (_) => [],
      'GET /requirements/mine': (_) => [],
      ...routes,
    });
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Clear any previous screen first, so a repeated call gets a fresh State
    // (and so reloads from the new fake API) instead of reusing the old one.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.dark(), home: const DashboardScreen()),
    );
    await tester.pumpAndSettle();
  }

  Finder navItem(IconData icon) => find.descendant(
      of: find.byType(CurvedNavBar), matching: find.byIcon(icon));

  testWidgets('shows an empty message when there are no active requests',
      (tester) async {
    await pumpScreen(tester, {});

    expect(find.text("You don't have any active requests."), findsOneWidget);
  });

  testWidgets('shows a progress card per active request, newest two only',
      (tester) async {
    await pumpScreen(tester, {
      'GET /requirements/mine': (_) => [
            requirementJson('r1', 'Sent request', 'SENT'),
            requirementJson('r2', 'Accepted request', 'ACCEPTED'),
            requirementJson('r3', 'Third request', 'CONFIRMED'),
          ],
    });

    expect(find.text('Sent request'), findsOneWidget);
    expect(find.text('Accepted request'), findsOneWidget);
    expect(find.text('Third request'), findsNothing,
        reason: 'only two cards are shown');
    // Each card has its own tag, and every card lists all four stepper labels.
    expect(find.text('Sent'), findsNWidgets(3));
    expect(find.text('Accepted'), findsNWidgets(3));
    expect(find.text('Bids'), findsNWidgets(2));
    expect(find.text('Confirmed'), findsNWidgets(2));
  });

  testWidgets('leaves completed requests out of the active list',
      (tester) async {
    await pumpScreen(tester, {
      'GET /requirements/mine': (_) =>
          [requirementJson('r1', 'Done request', 'COMPLETED')],
    });

    expect(find.text('Done request'), findsNothing);
    expect(find.text("You don't have any active requests."), findsOneWidget);
  });

  testWidgets('a request with bids shows the bid count and the lowest bid',
      (tester) async {
    await pumpScreen(tester, {
      'GET /requirements/mine': (_) => [
            requirementJson('r1', 'Fan request', 'BID_RECEIVED', bids: [
              bidJson('b1', min: 700),
              bidJson('b2', min: 600, refinedMin: 450),
              bidJson('b3', min: 800),
              bidJson('b4', min: 900),
            ]),
          ],
    });

    expect(find.text('4 bids'), findsOneWidget);
    expect(find.textContaining('Lowest bid'), findsOneWidget);
    expect(find.textContaining('₹450'), findsOneWidget,
        reason: 'a refined price counts');
    expect(find.textContaining('Compare and pick'), findsOneWidget);
  });

  testWidgets('labels confirmed and terminal statuses without a stepper',
      (tester) async {
    for (final entry in {
      'CONFIRMED': 'Confirmed',
      'REJECTED': 'Rejected',
      'CANCELLED': 'Cancelled',
      'EXPIRED': 'Expired'
    }.entries) {
      await pumpScreen(tester, {
        'GET /requirements/mine': (_) =>
            [requirementJson('r1', 'Job', entry.key)],
      });
      expect(find.text(entry.value), findsWidgets, reason: entry.key);
      expect(find.text('Job'), findsOneWidget);
    }
  });

  testWidgets('tapping a request card opens My Requests', (tester) async {
    await pumpScreen(tester, {
      'GET /requirements/mine': (_) =>
          [requirementJson('r1', 'Fan request', 'SENT')],
    });

    await tester.tap(find.text('Fan request'));
    await tester.pumpAndSettle();

    expect(find.byType(MyRequestsScreen), findsOneWidget);
  });

  testWidgets('survives the requests failing to load', (tester) async {
    await pumpScreen(tester, {
      'GET /requirements/mine': (_) => const FakeError(500, 'down'),
    });

    expect(find.text("You don't have any active requests."), findsOneWidget);
  });

  testWidgets(
      'the search bar, hero button and nearby prompt all open category browsing',
      (tester) async {
    await pumpScreen(tester, {});

    for (final tap in [
      find.text('Search electrician, plumber...'),
      find.text('Post requirement'),
      find.text('Browse a category'),
    ]) {
      await tester.tap(tap);
      await tester.pumpAndSettle();
      expect(find.byType(CategoryGridScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('See all and a service card open category browsing',
      (tester) async {
    await pumpScreen(tester, {});

    await tester.tap(find.text('See all').first);
    await tester.pumpAndSettle();
    expect(find.byType(CategoryGridScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Electrician'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryGridScreen), findsOneWidget);
  });

  testWidgets('View all and the Requests nav item open My Requests',
      (tester) async {
    await pumpScreen(tester, {});

    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    expect(find.byType(MyRequestsScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(navItem(OneHubIcons.documentList));
    await tester.pumpAndSettle();
    expect(find.byType(MyRequestsScreen), findsOneWidget);
  });

  testWidgets('the Category nav item opens category browsing', (tester) async {
    await pumpScreen(tester, {});

    await tester.tap(navItem(OneHubIcons.category));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryGridScreen), findsOneWidget);
  });

  testWidgets('the Profile nav item opens the profile screen', (tester) async {
    await pumpScreen(tester, {});

    await tester.tap(navItem(OneHubIcons.profile));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('the location chip says it is not set up yet', (tester) async {
    await pumpScreen(tester, {});

    await tester.tap(find.text('Edappally, Kochi'));
    await tester.pump();

    expect(find.text("Location detection isn't set up yet."), findsOneWidget);
  });

  testWidgets('the notification bell says it is not set up yet',
      (tester) async {
    await pumpScreen(tester, {});

    await tester.tap(find.byIcon(OneHubIcons.notification));
    await tester.pump();

    expect(find.text("Notifications aren't set up yet."), findsOneWidget);
  });

  testWidgets('pull to refresh reloads the requests', (tester) async {
    var requests = <Map<String, dynamic>>[];
    final fake = installFakeApi({
      'GET /categories': (_) => [],
      'GET /requirements/mine': (_) => requests,
    });
    // Short enough that the page scrolls, which pull-to-refresh needs.
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(theme: OneHubTheme.dark(), home: const DashboardScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Fresh request'), findsNothing);

    requests = [requirementJson('r9', 'Fresh request', 'SENT')];
    await tester.drag(find.byType(ListView).first, const Offset(0, 350));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(fake.calls.where((c) => c == 'GET /requirements/mine').length, 2);
    expect(find.text('Fresh request'), findsOneWidget);
  });
}
