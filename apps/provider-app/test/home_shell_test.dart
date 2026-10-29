import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/dashboard/dashboard_screen.dart';
import 'package:onehub_provider/features/home/home_shell.dart';
import 'package:onehub_provider/features/plans/plans_screen.dart';
import 'package:onehub_provider/features/profile/profile_screen.dart';
import 'package:onehub_provider/features/requirements/active_jobs_screen.dart';
import 'package:onehub_provider/features/requirements/incoming_requests_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  // Business details for the Profile tab; every list endpoint answers empty.
  ApiClient fakeClient() => ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          if (request.url.path == '/providers/me') {
            return http.Response(
                jsonEncode(
                    {'id': 'p1', 'coverageRadiusKm': 5, 'subServices': []}),
                200);
          }
          return http.Response(jsonEncode([]), 200);
        }),
      );

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(), home: HomeShell(client: fakeClient())));
    await tester.pumpAndSettle();
  }

  Finder navItem(IconData icon) => find.descendant(
      of: find.byType(CurvedNavBar), matching: find.byIcon(icon));

  int selectedTab(WidgetTester tester) =>
      tester.widget<CurvedNavBar>(find.byType(CurvedNavBar)).selectedIndex;

  testWidgets('starts on Home with the four tabs and Home active',
      (tester) async {
    await pumpShell(tester);

    final bar = tester.widget<CurvedNavBar>(find.byType(CurvedNavBar));
    expect(
        bar.items.map((i) => i.label), ['Home', 'Requests', 'Jobs', 'Profile']);
    expect(bar.selectedIndex, HomeTab.home);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  for (final (name, icon, tab, screen) in [
    ('Requests', OneHubIcons.work, HomeTab.requests, IncomingRequestsScreen),
    ('Jobs', OneHubIcons.documentList, HomeTab.jobs, ActiveJobsScreen),
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

  testWidgets('the dashboard tiles switch to the matching tab', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Incoming requests'));
    await tester.pumpAndSettle();
    expect(find.byType(IncomingRequestsScreen), findsOneWidget);
    expect(selectedTab(tester), HomeTab.requests);

    await tester.tap(navItem(OneHubIcons.home));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active jobs'));
    await tester.pumpAndSettle();
    expect(find.byType(ActiveJobsScreen), findsOneWidget);
    expect(selectedTab(tester), HomeTab.jobs);
  });

  testWidgets('a page opened from a tab covers the bar and has a back arrow',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(navItem(OneHubIcons.profile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plans'));
    await tester.pumpAndSettle();

    expect(find.byType(PlansScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(CurvedNavBar), findsNothing,
        reason: 'deeper pages are pushed over the whole shell');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(selectedTab(tester), HomeTab.profile);
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
