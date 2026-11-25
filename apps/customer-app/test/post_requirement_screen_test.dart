import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/profile/profile_state.dart';
import 'package:onehub_customer/features/requirements/post_requirement_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  final providers = [
    {
      'id': 'p1',
      'businessName': 'Asha Electricals',
      'averageRating': 4.5,
      'certified': true
    },
    {
      'id': 'p2',
      'user': {'fullName': 'Ravi Kumar'},
      'averageRating': 3.0,
      'certified': false,
    },
  ];

  // The customer's saved addresses; every fake API below serves them.
  final home = {
    'id': 'a1',
    'label': 'Home',
    'house': '12B, Palm Grove',
    'street': 'Changampuzha Nagar',
    'pincode': '682024',
    'city': 'Edappally',
    'latitude': 10.0261,
    'longitude': 76.3125,
  };
  final addressRoute = <String, Object? Function(dynamic)>{
    'GET /users/me/addresses': (_) => [home],
  };

  // Opens the screen from a button, with a stand-in '/dashboard' route, so a
  // successful submit can be seen landing on Home with the stack cleared.
  // The photo picker the screen gets; a test can make it back out.
  PhotoPicker pick = (_) async =>
      PickedPhoto(Uint8List.fromList([0xff, 0xd8, 0xff]), 'fan.jpg');

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        routes: {
          '/dashboard': (_) => const Scaffold(body: Text('HOME TAB')),
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => PostRequirementScreen(
                          subServiceId: 'sub-1',
                          pickPhoto: pick,
                          pickLocation: (_, __) async => const SavedLocation(
                              city: 'Aluva',
                              latitude: 10.1076,
                              longitude: 76.3516))),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> describe(WidgetTester tester, {String title = ' Fan repair '}) async {
    await tester.enterText(find.byKey(const Key('request-title')), title);
    await tester.enterText(
        find.byKey(const Key('request-description')), ' Fan is noisy ');
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(PrimaryCta, 'Send Request'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the form, with one GlowCard and the providers below it',
      (tester) async {
    installFakeApi({'GET /providers': (_) => providers});
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Tell us what you need'), findsOneWidget);
    expect(find.text('Any time works'), findsOneWidget);
    expect(find.text('Asha Electricals'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('4.5 ★'), findsOneWidget);
    expect(find.text('CERTIFIED'), findsOneWidget);
    expect(find.widgetWithText(PrimaryCta, 'Send Request'), findsOneWidget);
  });

  group('distance', () {
    tearDown(() => customerLocation.value = null);

    testWidgets('asks the API for providers near the saved location',
        (tester) async {
      customerLocation.value = const SavedLocation(
          city: 'Edappally', latitude: 10.0261, longitude: 76.3125);
      String? query;
      installFakeApi({
      ...addressRoute,
        'GET /providers': (r) {
          query = r.url.query;
          return [
            {...providers[0], 'distanceKm': 3.4},
            {...providers[1], 'distanceKm': 0.6},
          ];
        },
      });
      await pumpScreen(tester);

      expect(query, 'subServiceId=sub-1&latitude=10.0261&longitude=76.3125');
      expect(find.text('Nearest first, from Edappally.'), findsOneWidget);
      expect(find.text('3.4 km away'), findsOneWidget);
      expect(find.text('600 m away'), findsOneWidget);
    });

    testWidgets('without an address it says to add one, and cannot send',
        (tester) async {
      String? query;
      final fake = installFakeApi({
        'GET /users/me/addresses': (_) => [],
        'GET /providers': (r) {
          query = r.url.query;
          return providers;
        },
      });
      await pumpScreen(tester);

      expect(query, 'subServiceId=sub-1');
      expect(find.text('Add the job address to see the nearest first.'),
          findsOneWidget);
      expect(find.textContaining('away'), findsNothing);

      await describe(tester);
      await tester.tap(find.text('Asha Electricals'));
      await send(tester);
      expect(find.text('Add the address for this job.'), findsOneWidget);
      expect(fake.calls.where((c) => c.startsWith('POST')), isEmpty);
    });

    testWidgets('another address re-lists providers from there, and a new one can be added',
        (tester) async {
      final queries = <String>[];
      final office = {
        ...home,
        'id': 'a2',
        'label': 'Office',
        'city': 'Kakkanad',
        'latitude': 10.0159,
        'longitude': 76.3419,
      };
      final fake = installFakeApi({
        'GET /users/me/addresses': (_) => [home, office],
        'GET /providers': (r) {
          queries.add(r.url.query);
          return providers;
        },
        'POST /users/me/addresses': (_) =>
            {...office, 'id': 'a3', 'label': 'Other', 'city': 'Aluva'},
        'POST /requirements': (_) => {'id': 'r1'},
      });
      await pumpScreen(tester);
      expect(find.text('Nearest first, from Edappally.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('address-a2')));
      await tester.pumpAndSettle();
      expect(queries.last, 'subServiceId=sub-1&latitude=10.0159&longitude=76.3419');
      expect(find.text('Nearest first, from Kakkanad.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-address')));
      await tester.pumpAndSettle();
      expect(find.text('Add address'), findsWidgets);
      await tester.enterText(find.byKey(const Key('address-house')), '1');
      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();
      expect(find.text('Set the address on the map: use GPS or pick your area.'),
          findsOneWidget);
      await tester.tap(find.byKey(const Key('address-location')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('address-street')), 'Bank Road');
      await tester.enterText(find.byKey(const Key('address-pincode')), '683101');
      await tester.tap(find.byKey(const Key('address-label-Other')));
      await tester.tap(find.text('Save address'));
      await tester.pumpAndSettle();

      expect(fake.bodies.last, {
        'label': 'Other',
        'house': '1',
        'street': 'Bank Road',
        'pincode': '683101',
        'city': 'Aluva',
        'latitude': 10.1076,
        'longitude': 76.3516,
      });
      expect(find.text('Nearest first, from Aluva.'), findsOneWidget);

      await describe(tester);
      await tester.tap(find.text('Asha Electricals'));
      await send(tester);
      expect(fake.bodies.last['addressId'], 'a3');
    });
  });

  testWidgets('shows a loading spinner for the providers only', (tester) async {
    installFakeApi({'GET /providers': (_) => providers});
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        home: const PostRequirementScreen(subServiceId: 'sub-1'),
      ),
    );

    expect(find.text('Tell us what you need'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows an empty message when no providers are nearby',
      (tester) async {
    installFakeApi({'GET /providers': (_) => []});
    await pumpScreen(tester);

    expect(find.text('No providers found nearby. Try widening your search.'),
        findsOneWidget);
  });

  testWidgets('shows an error when the providers cannot be loaded',
      (tester) async {
    installFakeApi({'GET /providers': (_) => const FakeError(500, 'down')});
    await pumpScreen(tester);

    expect(find.textContaining('Could not load providers'), findsOneWidget);
  });

  testWidgets('tapping a provider selects it and tapping again clears it',
      (tester) async {
    installFakeApi({'GET /providers': (_) => providers});
    await pumpScreen(tester);

    expect(find.byIcon(OneHubIcons.confirmed), findsNothing);
    await tester.tap(find.text('Asha Electricals'));
    await tester.pump();
    expect(find.byIcon(OneHubIcons.confirmed), findsOneWidget);

    await tester.tap(find.text('Asha Electricals'));
    await tester.pump();
    expect(find.byIcon(OneHubIcons.confirmed), findsNothing);
  });

  testWidgets('needs a description and at least one provider before sending',
      (tester) async {
    final fake = installFakeApi({'GET /providers': (_) => providers});
    await pumpScreen(tester);

    await send(tester);
    expect(find.text('Add a title, describe the work and select at least one provider.'),
        findsOneWidget);

    await describe(tester);
    await send(tester);
    expect(find.text('Add a title, describe the work and select at least one provider.'),
        findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('POST')), isEmpty);
  });

  testWidgets('a blank title stops the request', (tester) async {
    final fake = installFakeApi({'GET /providers': (_) => providers});
    await pumpScreen(tester);

    await describe(tester, title: '   ');
    await tester.tap(find.text('Asha Electricals'));
    await send(tester);

    expect(
        find.text(
            'Add a title, describe the work and select at least one provider.'),
        findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('POST')), isEmpty);
  });

  testWidgets('the title field is limited to the API maximum', (tester) async {
    installFakeApi({'GET /providers': (_) => providers});
    await pumpScreen(tester);

    final field =
        tester.widget<TextField>(find.byKey(const Key('request-title')));
    expect(field.maxLength, requestTitleMaxLength);
    expect(find.textContaining('TITLE', findRichText: true), findsOneWidget);
  });

  testWidgets('sends the request and goes to Home with nothing to go back to',
      (tester) async {
    final fake = installFakeApi({
      ...addressRoute,
      'GET /providers': (_) => providers,
      'POST /requirements': (_) => {'id': 'r1'},
    });
    await pumpScreen(tester);
    await describe(tester);
    await tester.tap(find.text('Asha Electricals'));
    await tester.tap(find.text('Ravi Kumar'));
    await send(tester);

    expect(fake.bodies.single['subServiceId'], 'sub-1');
    expect(fake.bodies.single['addressId'], 'a1');
    expect(fake.bodies.single['title'], 'Fan repair');
    expect(fake.bodies.single['description'], 'Fan is noisy');
    expect(fake.bodies.single['providerIds'], ['p1', 'p2']);
    expect(fake.bodies.single.containsKey('preferredAt'), isFalse);
    expect(find.text('HOME TAB'), findsOneWidget);
    expect(find.byType(PostRequirementScreen), findsNothing);
    expect(find.text('open'), findsNothing);
    final home = tester.element(find.text('HOME TAB'));
    expect(Navigator.of(home).canPop(), isFalse);
    expect(find.text('Request sent. Providers will reply with their prices.'),
        findsOneWidget);
  });

  testWidgets('includes the preferred date when one is picked', (tester) async {
    final fake = installFakeApi({
      ...addressRoute,
      'GET /providers': (_) => providers,
      'POST /requirements': (_) => {'id': 'r1'},
    });
    await pumpScreen(tester);
    await describe(tester);
    await tester.tap(find.text('Asha Electricals'));

    await tester.tap(find.text('Any time works'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Any time works'), findsNothing);
    await send(tester);

    expect(fake.bodies.single['preferredAt'], isNotNull);
  });

  testWidgets('cancelling the date picker leaves the date unset',
      (tester) async {
    installFakeApi({'GET /providers': (_) => providers});
    await pumpScreen(tester);

    await tester.tap(find.text('Any time works'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Any time works'), findsOneWidget);
  });

  testWidgets('shows the server error and stays on the form when sending fails',
      (tester) async {
    installFakeApi({
      ...addressRoute,
      'GET /providers': (_) => providers,
      'POST /requirements': (_) => const FakeError(500, 'down'),
    });
    await pumpScreen(tester);
    await describe(tester);
    await tester.tap(find.text('Asha Electricals'));
    await send(tester);

    expect(find.textContaining('Could not send the request'), findsOneWidget);
    expect(find.byType(PostRequirementScreen), findsOneWidget);
  });

  group('photos', () {
    var uploads = 0;
    Map<String, Object? Function(dynamic)> routes({bool failUpload = false}) => {
          ...addressRoute,
          'GET /providers': (_) => providers,
          'POST /uploads/photo': (_) => failUpload
              ? const FakeError(400, 'only JPEG, PNG or WebP images can be uploaded')
              : {'url': '/api/v1/uploads/photos/p${uploads++}.jpg'},
          'POST /requirements': (_) => {'id': 'r1'},
        };

    setUp(() {
      uploads = 0;
      pick = (_) async =>
          PickedPhoto(Uint8List.fromList([0xff, 0xd8, 0xff]), 'fan.jpg');
    });

    Future<void> addPhoto(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('add-photo')));
      await tester.pumpAndSettle();
    }

    testWidgets('a picked photo is uploaded straight away and sent with the request',
        (tester) async {
      final fake = installFakeApi(routes());
      await pumpScreen(tester);

      expect(find.text('PHOTOS (OPTIONAL)', findRichText: true), findsOneWidget);
      await addPhoto(tester);
      await addPhoto(tester);

      expect(fake.calls.where((c) => c == 'POST /uploads/photo'), hasLength(2));
      expect(find.byType(PhotoThumb), findsNWidgets(2));

      await describe(tester);
      await tester.tap(find.text('Asha Electricals'));
      await send(tester);

      expect(fake.bodies.single['photoUrls'], [
        '/api/v1/uploads/photos/p0.jpg',
        '/api/v1/uploads/photos/p1.jpg',
      ]);
    });

    testWidgets('a removed photo is not sent, and no photos sends no list',
        (tester) async {
      final fake = installFakeApi(routes());
      await pumpScreen(tester);

      await addPhoto(tester);
      await tester.tap(find.bySemanticsLabel('Remove photo'));
      await tester.pump();
      expect(find.byType(PhotoThumb), findsNothing);

      await describe(tester);
      await tester.tap(find.text('Asha Electricals'));
      await send(tester);

      expect(fake.bodies.single.containsKey('photoUrls'), isFalse);
    });

    testWidgets('the add button goes once there are five', (tester) async {
      installFakeApi(routes());
      await pumpScreen(tester);

      for (var i = 0; i < maxRequestPhotos; i++) {
        await addPhoto(tester);
      }

      expect(find.byType(PhotoThumb), findsNWidgets(maxRequestPhotos));
      expect(find.byKey(const Key('add-photo')), findsNothing);
    });

    testWidgets('backing out of the picker uploads nothing', (tester) async {
      final fake = installFakeApi(routes());
      pick = (_) async => null;
      await pumpScreen(tester);

      await addPhoto(tester);

      expect(fake.calls.where((c) => c.startsWith('POST /uploads')), isEmpty);
    });

    testWidgets('a refused upload says why', (tester) async {
      installFakeApi(routes(failUpload: true));
      await pumpScreen(tester);

      await addPhoto(tester);

      expect(
          find.text(
              'Could not add the photo: only JPEG, PNG or WebP images can be uploaded'),
          findsOneWidget);
      expect(find.byType(PhotoThumb), findsNothing);
    });
  });
}
