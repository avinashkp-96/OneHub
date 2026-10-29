import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/categories/category_grid_screen.dart';
import 'package:onehub_customer/features/categories/sub_service_list_screen.dart';
import 'package:onehub_customer/features/dashboard/dashboard_screen.dart';
import 'package:onehub_customer/features/home/home_shell.dart';
import 'package:onehub_customer/features/profile/profile_screen.dart';
import 'package:onehub_customer/features/requirements/my_requests_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  Future<FakeApi> pumpShell(WidgetTester tester) async {
    final fake = installFakeApi({
      'GET /requirements/mine': (_) => [],
      'GET /categories': (_) => [
            {'id': 'c1', 'name': 'Electrician'}
          ],
      'GET /categories/c1/sub-services': (_) => [],
    });
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(theme: OneHubTheme.dark(), home: const HomeShell()));
    await tester.pumpAndSettle();
    return fake;
  }

  Finder navItem(IconData icon) => find.descendant(
      of: find.byType(CurvedNavBar), matching: find.byIcon(icon));

  int selectedTab(WidgetTester tester) =>
      tester.widget<CurvedNavBar>(find.byType(CurvedNavBar)).selectedIndex;

  testWidgets('starts on Home with the four tabs and Home active',
      (tester) async {
    await pumpShell(tester);

    final bar = tester.widget<CurvedNavBar>(find.byType(CurvedNavBar));
    expect(bar.items.map((i) => i.label),
        ['Home', 'Requests', 'Category', 'Profile']);
    expect(bar.selectedIndex, HomeTab.home);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  for (final (name, icon, tab, screen) in [
    ('Requests', OneHubIcons.documentList, HomeTab.requests, MyRequestsScreen),
    ('Category', OneHubIcons.category, HomeTab.category, CategoryGridScreen),
    ('Profile', OneHubIcons.profile, HomeTab.profile, ProfileScreen),
  ]) {
    testWidgets(
        'the $name tab keeps the bottom bar, marks it active and has no back arrow',
        (tester) async {
      await pumpShell(tester);

      await tester.tap(navItem(icon));
      await tester.pumpAndSettle();

      expect(find.byType(screen), findsOneWidget);
      expect(find.byType(CurvedNavBar), findsOneWidget);
      expect(selectedTab(tester), tab);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(DashboardScreen), findsNothing);
    });
  }

  testWidgets('Home returns to the dashboard and reloads its requests',
      (tester) async {
    final fake = await pumpShell(tester);

    await tester.tap(navItem(OneHubIcons.profile));
    await tester.pumpAndSettle();
    await tester.tap(navItem(OneHubIcons.home));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(selectedTab(tester), HomeTab.home);
    expect(fake.calls.where((c) => c == 'GET /requirements/mine').length, 2);
  });

  testWidgets('dashboard shortcuts switch to the matching tab', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    expect(find.byType(MyRequestsScreen), findsOneWidget);
    expect(selectedTab(tester), HomeTab.requests);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('a page opened from a tab covers the bar and has a back arrow',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(navItem(OneHubIcons.category));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electrician'));
    await tester.pumpAndSettle();

    expect(find.byType(SubServiceListScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(CurvedNavBar), findsNothing,
        reason: 'deeper pages are pushed over the whole shell');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryGridScreen), findsOneWidget);
    expect(selectedTab(tester), HomeTab.category);
  });

  testWidgets('system back on another tab goes to Home, not out of the app',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(navItem(OneHubIcons.documentList));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(selectedTab(tester), HomeTab.home);
  });
}
