import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_shared/onehub_shared.dart';

/// Stands in for the platform location service.
class FakeGeolocator extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission afterRequest = LocationPermission.whileInUse;
  int requests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return afterRequest;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async =>
      Position(
        latitude: 10.0261,
        longitude: 76.3125,
        timestamp: DateTime(2026),
        accuracy: 20,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final stored = <String, String>{};
  setUp(() {
    stored
      ..clear()
      ..['access_token'] = 'tok';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        return switch (call.method) {
          'read' => stored[args['key']],
          'write' => stored[args['key'] as String] = args['value'] as String,
          'delete' => stored.remove(args['key']),
          _ => null,
        };
      },
    );
  });

  final areas = [
    {'name': 'Edappally', 'latitude': 10.0261, 'longitude': 76.3125},
    {'name': 'Kakkanad', 'latitude': 10.0159, 'longitude': 76.3419},
  ];

  // An API answering the two location routes; [failAreas] breaks the list.
  late List<String> seen;
  ApiClient fakeApi({bool failAreas = false, bool failPlace = false}) {
    seen = [];
    return ApiClient(
      baseUrl: 'https://example.test/api/v1',
      httpClient: MockClient((request) async {
        seen.add('${request.method} ${request.url.path}?${request.url.query}');
        final path = request.url.path;
        if (path.endsWith('/locations/areas')) {
          return failAreas
              ? http.Response('{"message":"down"}', 500)
              : http.Response(jsonEncode(areas), 200);
        }
        if (path.endsWith('/locations/place')) {
          return failPlace
              ? http.Response('{"message":"down"}', 500)
              : http.Response(jsonEncode({'city': 'Edappally'}), 200);
        }
        if (path.endsWith('/users/me/location')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
              jsonEncode({'id': 'u1', ...body, 'city': 'Kakkanad'}), 200);
        }
        return http.Response('{"message":"not found"}', 404);
      }),
    );
  }

  group('SavedLocation', () {
    test('reads a user, and is null without coordinates', () {
      final l = SavedLocation.fromJson(
          {'city': 'Edappally', 'latitude': 10, 'longitude': 76.5})!;
      expect(l.city, 'Edappally');
      expect(l.latitude, 10.0);
      expect(l.query, 'latitude=10.0&longitude=76.5');
      expect(l.toJson(), {'city': 'Edappally', 'latitude': 10.0, 'longitude': 76.5});

      expect(SavedLocation.fromJson({'city': 'Kochi', 'latitude': null}), isNull);
      expect(SavedLocation.fromJson(null), isNull);
      expect(SavedLocation.fromJson({'latitude': 1, 'longitude': 2})!.city,
          'Your location');
    });

    test('distanceLabel uses metres under a kilometre', () {
      expect(distanceLabel(0.43), '430 m away');
      expect(distanceLabel(3.44), '3.4 km away');
    });
  });

  Widget app(Widget child) =>
      MaterialApp(theme: OneHubTheme.dark(), home: Scaffold(body: child));

  // Opens the sheet from a button and records what it returns.
  Future<List<SavedLocation?>> open(WidgetTester tester, ApiClient api,
      {SavedLocation? current, PositionFinder? locate}) async {
    final results = <SavedLocation?>[];
    await tester.pumpWidget(app(Builder(
      builder: (context) => TextButton(
        onPressed: () async => results.add(await chooseLocation(context, api,
            current: current,
            findPosition: locate ??
                () async => (latitude: 10.0262, longitude: 76.3126))),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('lists the areas, marks the current one, and returns a pick',
      (tester) async {
    final results = await open(tester, fakeApi(),
        current: const SavedLocation(
            city: 'Kakkanad', latitude: 10.0159, longitude: 76.3419));

    expect(find.text('Choose your location'), findsOneWidget);
    expect(find.text('Use my current location'), findsOneWidget);
    expect(find.text('Edappally'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('area-Kakkanad')),
            matching: find.byIcon(OneHubIcons.successCheck)),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('area-Edappally')));
    await tester.pumpAndSettle();

    expect(results.single!.city, 'Edappally');
    expect(results.single!.latitude, 10.0261);
  });

  testWidgets('current location is named by the API', (tester) async {
    final api = fakeApi();
    final results = await open(tester, api);

    await tester.tap(find.byKey(const Key('use-gps')));
    await tester.pumpAndSettle();

    expect(seen.last, 'GET /api/v1/locations/place?latitude=10.0262&longitude=76.3126');
    expect(results.single!.city, 'Edappally');
    expect(results.single!.latitude, 10.0262);
  });

  testWidgets('location turned off says so and keeps the sheet open',
      (tester) async {
    final results = await open(tester, fakeApi(),
        locate: () async => throw const LocationUnavailable('Location is off.'));

    await tester.tap(find.byKey(const Key('use-gps')));
    await tester.pumpAndSettle();

    expect(find.text('Location is off.'), findsOneWidget);
    expect(find.text('Choose your location'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('a failed lookup asks to try again or pick an area',
      (tester) async {
    await open(tester, fakeApi(failPlace: true));

    await tester.tap(find.byKey(const Key('use-gps')));
    await tester.pumpAndSettle();

    expect(
        find.text(
            'Could not find your location. Try again, or pick your area below.'),
        findsOneWidget);
  });

  testWidgets('says so when the areas cannot load, and backing out gives null',
      (tester) async {
    final results = await open(tester, fakeApi(failAreas: true));

    expect(find.text('Could not load the areas.'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(results, [null]);
  });

  test('saveMyLocation sends PUT /users/me/location and reads the answer',
      () async {
    final api = fakeApi();

    final saved = await saveMyLocation(
        api,
        const SavedLocation(
            city: 'Here', latitude: 10.0159, longitude: 76.3419));

    expect(seen.single, startsWith('PUT /api/v1/users/me/location'));
    expect(saved.city, 'Kakkanad');
  });

  group('currentPosition', () {
    late FakeGeolocator geo;
    setUp(() => GeolocatorPlatform.instance = geo = FakeGeolocator());

    test('reads the position when allowed', () async {
      final p = await currentPosition();
      expect(p.latitude, 10.0261);
      expect(geo.requests, 0);
    });

    test('asks the first time, and gives up if refused', () async {
      geo.permission = LocationPermission.denied;
      geo.afterRequest = LocationPermission.denied;

      await expectLater(
          currentPosition(),
          throwsA(isA<LocationUnavailable>().having((e) => e.toString(),
              'message', contains('not allowed to use your location'))));
      expect(geo.requests, 1);

      geo.afterRequest = LocationPermission.whileInUse;
      expect((await currentPosition()).longitude, 76.3125);
    });

    test('location services off', () async {
      geo.enabled = false;
      await expectLater(
          currentPosition(),
          throwsA(isA<LocationUnavailable>()
              .having((e) => e.message, 'message', contains('turned off'))));
    });
  });
}
