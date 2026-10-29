import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/core/widgets/service_tile.dart';
import 'package:onehub_provider/features/business/business_details_screen.dart';
import 'package:onehub_provider/features/profile/profile_screen.dart';
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

  const subServicesByCategory = {
    'c1': [
      {'id': 's1', 'categoryId': 'c1', 'name': 'Fan Installation'},
      {'id': 's2', 'categoryId': 'c1', 'name': 'Light Fitting'},
      {'id': 's3', 'categoryId': 'c1', 'name': 'House Wiring'},
    ],
    'c2': [
      {'id': 's5', 'categoryId': 'c2', 'name': 'Leak Repair'},
      {'id': 's6', 'categoryId': 'c2', 'name': 'Tap Installation'},
    ],
  };

  late Map<String, dynamic> saved;
  late List<Map<String, dynamic>> patches;

  // A fake backend that remembers what PATCH /providers/me saved, so the
  // Profile card can be checked after it reloads.
  ApiClient fakeClient({bool failLoad = false, bool failSave = false}) {
    saved = {
      'id': 'p1',
      'yearsExperience': 8,
      'coverageRadiusKm': 10,
      'category': {'id': 'c1', 'name': 'Electrician'},
      'subServices': [
        {'id': 's1', 'name': 'Fan Installation'},
        {'id': 's2', 'name': 'Light Fitting'},
      ],
    };
    patches = [];
    return ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path == '/providers/me') {
          if (request.method == 'PATCH') {
            if (failSave) {
              return http.Response(
                  jsonEncode({'message': 'sub-services must all belong to one category'}),
                  400);
            }
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            patches.add(body);
            final ids = (body['subServiceIds'] as List).cast<String>();
            final all = subServicesByCategory.values.expand((l) => l);
            final chosen = all.where((s) => ids.contains(s['id'])).toList();
            final categoryId = chosen.first['categoryId'];
            saved = {
              'id': 'p1',
              'yearsExperience': body['yearsExperience'],
              'coverageRadiusKm': body['coverageRadiusKm'],
              'category': {
                'id': categoryId,
                'name': categoryId == 'c1' ? 'Electrician' : 'Plumber'
              },
              'subServices': [
                for (final s in chosen) {'id': s['id'], 'name': s['name']}
              ],
            };
            return http.Response(jsonEncode(saved), 200);
          }
          if (failLoad) {
            return http.Response(jsonEncode({'message': 'down'}), 500);
          }
          return http.Response(jsonEncode(saved), 200);
        }
        if (path == '/categories') {
          return http.Response(
              jsonEncode([
                {'id': 'c1', 'name': 'Electrician'},
                {'id': 'c2', 'name': 'Plumber'},
              ]),
              200);
        }
        final match = RegExp(r'^/categories/(\w+)/sub-services$').firstMatch(path);
        if (match != null) {
          return http.Response(
              jsonEncode(subServicesByCategory[match.group(1)] ?? []), 200);
        }
        return http.Response(jsonEncode([]), 200);
      }),
    );
  }

  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // Opens the screen on top of a stand-in so Save (which pops) has somewhere
  // to go and its message has a Scaffold to show on.
  Future<void> pumpScreen(WidgetTester tester, ApiClient client) async {
    tallView(tester);
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BusinessDetailsScreen(client: client))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool selected(WidgetTester tester, String label) => tester
      .widget<ServiceTile>(find.widgetWithText(ServiceTile, label))
      .selected;

  TextField field(WidgetTester tester, int index) =>
      tester.widgetList<TextField>(find.byType(TextField)).elementAt(index);

  testWidgets('loads the saved experience, coverage, category and services',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Business details'), findsOneWidget);
    expect(field(tester, 0).controller!.text, '8');
    expect(field(tester, 1).controller!.text, '10');
    expect(selected(tester, 'Electrician'), isTrue);
    expect(selected(tester, 'Plumber'), isFalse);
    expect(selected(tester, 'Fan Installation'), isTrue);
    expect(selected(tester, 'Light Fitting'), isTrue);
    expect(selected(tester, 'House Wiring'), isFalse);
  });

  testWidgets('saves the changes, pops and confirms', (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.enterText(find.byType(TextField).at(0), '9');
    await tester.enterText(find.byType(TextField).at(1), '15');
    await tester.tap(find.text('House Wiring'));
    await tester.tap(find.text('Light Fitting'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(patches, hasLength(1));
    expect(patches.single['yearsExperience'], 9);
    expect(patches.single['coverageRadiusKm'], 15);
    expect((patches.single['subServiceIds'] as List).toSet(), {'s1', 's3'});
    expect(find.byType(BusinessDetailsScreen), findsNothing);
    expect(find.text('Business details saved.'), findsOneWidget);
  });

  testWidgets('a blank experience is sent as cleared', (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.enterText(find.byType(TextField).at(0), '');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(patches.single.containsKey('yearsExperience'), isTrue);
    expect(patches.single['yearsExperience'], isNull);
  });

  testWidgets(
      'switching category clears the services; switching back restores them',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.tap(find.text('Plumber'));
    await tester.pumpAndSettle();
    expect(selected(tester, 'Plumber'), isTrue);
    expect(find.text('Leak Repair'), findsOneWidget);
    expect(find.text('Fan Installation'), findsNothing);
    expect(selected(tester, 'Leak Repair'), isFalse);

    await tester.tap(find.text('Electrician'));
    await tester.pumpAndSettle();
    expect(selected(tester, 'Fan Installation'), isTrue);
    expect(selected(tester, 'Light Fitting'), isTrue);
  });

  testWidgets('moving to another category saves only that category\'s services',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.tap(find.text('Plumber'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leak Repair'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(patches.single['subServiceIds'], ['s5']);
  });

  testWidgets('requires at least one service', (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.tap(find.text('Fan Installation'));
    await tester.tap(find.text('Light Fitting'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(find.text('Pick at least one service you offer.'), findsOneWidget);
    expect(patches, isEmpty);
    expect(find.byType(BusinessDetailsScreen), findsOneWidget);
  });

  testWidgets('rejects experience that is not a whole number from 0 to 60',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    for (final bad in ['abc', '-1', '61', '2.5']) {
      await tester.enterText(find.byType(TextField).at(0), bad);
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(find.text('Experience must be a whole number from 0 to 60.'),
          findsOneWidget,
          reason: bad);
    }
    expect(patches, isEmpty);
  });

  testWidgets('rejects coverage outside 1 to 100 km', (tester) async {
    await pumpScreen(tester, fakeClient());

    for (final bad in ['', '0', '101', 'far']) {
      await tester.enterText(find.byType(TextField).at(1), bad);
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(find.text('Coverage must be between 1 and 100 km.'), findsOneWidget,
          reason: bad);
    }
    expect(patches, isEmpty);
  });

  testWidgets('a failed save keeps the screen open with the reason',
      (tester) async {
    await pumpScreen(tester, fakeClient(failSave: true));

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(BusinessDetailsScreen), findsOneWidget);
    expect(find.textContaining('Could not save your business details'),
        findsOneWidget);
    expect(find.textContaining('one category'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('a failed load shows the reason and no form', (tester) async {
    await pumpScreen(tester, fakeClient(failLoad: true));

    expect(find.textContaining('Could not load your business details'),
        findsOneWidget);
    expect(find.byType(GlowCard), findsNothing);
    expect(find.text('Save changes'), findsNothing);
  });

  testWidgets('Profile Edit opens this screen and shows the saved values after',
      (tester) async {
    tallView(tester);
    final client = fakeClient();
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(), home: ProfileScreen(client: client)));
    await tester.pumpAndSettle();
    expect(find.text('8 years'), findsOneWidget);
    expect(find.text('2 services'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(BusinessDetailsScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.tap(find.text('House Wiring'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(BusinessDetailsScreen), findsNothing);
    expect(find.text('1 year'), findsOneWidget);
    expect(find.text('3 services'), findsOneWidget);
  });
}
