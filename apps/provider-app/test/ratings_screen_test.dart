import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/profile/profile_screen.dart';
import 'package:onehub_provider/features/ratings/ratings_screen.dart';
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

  final now = DateTime(2026, 10, 29, 12);
  String ago(Duration d) => now.subtract(d).toUtc().toIso8601String();

  Map<String, dynamic> summary() => {
        'averageRating': 4.3,
        'ratingCount': 3,
        'distribution': {'5': 2, '4': 0, '3': 0, '2': 1, '1': 0},
        'reviews': [
          {
            'id': 'r1',
            'stars': 5,
            'feedback': 'Quick and tidy',
            'createdAt': ago(const Duration(minutes: 30)),
            'customerName': 'Meera N.',
          },
          {
            'id': 'r2',
            'stars': 5,
            'feedback': null,
            'createdAt': ago(const Duration(days: 3)),
            'customerName': 'Arun K.',
          },
          {
            'id': 'r3',
            'stars': 2,
            'feedback': 'Came late',
            'createdAt': ago(const Duration(days: 20)),
            'customerName': 'Divya',
          },
        ],
      };

  ApiClient fakeClient({Object? body, bool fail = false}) => ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          if (fail) return http.Response(jsonEncode({'message': 'down'}), 500);
          if (request.url.path == '/ratings/mine') {
            return http.Response.bytes(
                utf8.encode(jsonEncode(body ?? summary())), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          if (request.url.path == '/providers/me') {
            return http.Response(
                jsonEncode({'id': 'p1', 'coverageRadiusKm': 5, 'subServices': []}),
                200);
          }
          return http.Response(jsonEncode([]), 200);
        }),
      );

  Future<void> pumpScreen(WidgetTester tester, ApiClient client) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: RatingsScreen(client: client, clock: () => now),
    ));
    await tester.pumpAndSettle();
  }

  double bar(WidgetTester tester, int stars) => tester
      .widget<LinearProgressIndicator>(find.byKey(Key('ratings-bar-$stars')))
      .value!;

  testWidgets('shows the average, count and star distribution',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Ratings')),
        findsOneWidget);
    expect(find.text('4.3'), findsOneWidget);
    expect(find.text('3 ratings'), findsOneWidget);
    expect(bar(tester, 5), 1.0, reason: 'the most common rating fills its bar');
    expect(bar(tester, 2), 0.5);
    expect(bar(tester, 4), 0.0);
  });

  testWidgets('lists each review with name, time and feedback',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    expect(find.text('Meera N.'), findsOneWidget);
    expect(find.text('Quick and tidy'), findsOneWidget);
    expect(find.text('30 min ago'), findsOneWidget);
    expect(find.text('Arun K.'), findsOneWidget);
    expect(find.text('No written feedback.'), findsOneWidget);
    expect(find.text('3 days ago'), findsOneWidget);
    expect(find.text('Divya'), findsOneWidget);
    expect(find.text('9 Oct'), findsOneWidget);
  });

  testWidgets('shows an empty state before any ratings', (tester) async {
    await pumpScreen(
        tester,
        fakeClient(body: {
          'averageRating': 0,
          'ratingCount': 0,
          'distribution': {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0},
          'reviews': [],
        }));

    expect(find.text('–'), findsOneWidget);
    expect(find.text('0 ratings'), findsOneWidget);
    expect(find.textContaining('No ratings yet'), findsOneWidget);
    expect(bar(tester, 5), 0.0);
  });

  testWidgets('says "1 rating" for a single one', (tester) async {
    final one = summary()
      ..['ratingCount'] = 1
      ..['averageRating'] = 5
      ..['reviews'] = [(summary()['reviews'] as List).first];
    await pumpScreen(tester, fakeClient(body: one));

    expect(find.text('1 rating'), findsOneWidget);
    expect(find.text('5.0'), findsOneWidget);
  });

  testWidgets('says so when the ratings cannot load', (tester) async {
    await pumpScreen(tester, fakeClient(fail: true));

    expect(find.textContaining('Could not load your ratings'), findsOneWidget);
    expect(find.byType(GlowCard), findsNothing);
  });

  testWidgets('Profile has a Ratings link that opens this screen',
      (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(), home: ProfileScreen(client: fakeClient())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ratings'));
    await tester.pumpAndSettle();

    expect(find.byType(RatingsScreen), findsOneWidget);
    expect(find.text('Meera N.'), findsOneWidget);
  });
}
