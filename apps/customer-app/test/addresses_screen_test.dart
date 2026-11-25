import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/addresses/address_form.dart';
import 'package:onehub_customer/features/addresses/addresses_screen.dart';
import 'package:onehub_customer/features/requirements/my_requests_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  Map<String, Object> address(String id, String label, String city) => {
        'id': id,
        'label': label,
        'house': '12B, Palm Grove',
        'street': 'Changampuzha Nagar',
        'pincode': '682024',
        'city': city,
        'latitude': 10.0261,
        'longitude': 76.3125,
      };

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: AddressesScreen(
          pickLocation: (_, __) async => const SavedLocation(
              city: 'Kakkanad', latitude: 10.0159, longitude: 76.3419)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the saved addresses', (tester) async {
    installFakeApi({
      'GET /users/me/addresses': (_) =>
          [address('a1', 'Home', 'Edappally'), address('a2', 'Office', 'Kakkanad')],
    });
    await pump(tester);

    expect(find.text('Saved addresses'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('OFFICE'), findsOneWidget);
    expect(find.textContaining('PIN 682024'), findsNWidgets(2));
  });

  testWidgets('adds an address and shows it', (tester) async {
    var saved = [address('a1', 'Home', 'Edappally')];
    final fake = installFakeApi({
      'GET /users/me/addresses': (_) => saved,
      'POST /users/me/addresses': (_) {
        saved = [...saved, address('a2', 'Office', 'Kakkanad')];
        return saved.last;
      },
    });
    await pump(tester);

    await tester.tap(find.byKey(const Key('add-address')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('address-location')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('address-house')), '4th floor, Tower A');
    await tester.enterText(find.byKey(const Key('address-street')), 'Infopark');
    await tester.enterText(find.byKey(const Key('address-pincode')), '682042');
    await tester.tap(find.byKey(const Key('address-label-Office')));
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    expect(fake.bodies.single, {
      'label': 'Office',
      'house': '4th floor, Tower A',
      'street': 'Infopark',
      'pincode': '682042',
      'city': 'Kakkanad',
      'latitude': 10.0159,
      'longitude': 76.3419,
    });
    expect(find.text('Address saved.'), findsOneWidget);
    expect(find.text('OFFICE'), findsOneWidget);
  });

  testWidgets('a refused save keeps the form open with the reason',
      (tester) async {
    installFakeApi({
      'GET /users/me/addresses': (_) => [address('a1', 'Home', 'Edappally')],
      'POST /users/me/addresses': (_) =>
          const FakeError(400, 'pincode must be a 6-digit PIN code'),
    });
    await pump(tester);
    await tester.tap(find.byKey(const Key('add-address')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('address-location')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('address-house')), '1');
    await tester.enterText(find.byKey(const Key('address-street')), 'MG Road');
    await tester.enterText(find.byKey(const Key('address-pincode')), '682042');
    await tester.tap(find.text('Save address'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not save the address'), findsOneWidget);
    expect(find.text('Save address'), findsOneWidget);
  });

  testWidgets('deletes an address after asking, and says when it cannot',
      (tester) async {
    var saved = [address('a1', 'Home', 'Edappally'), address('a2', 'Office', 'Kakkanad')];
    final fake = installFakeApi({
      'GET /users/me/addresses': (_) => saved,
      'DELETE /users/me/addresses/a2': (_) {
        saved = [saved.first];
        return {'deleted': 'a2'};
      },
      'DELETE /users/me/addresses/a1': (_) =>
          const FakeError(400, 'keep at least one address'),
    });
    await pump(tester);

    await tester.tap(find.descendant(
        of: find.byKey(const Key('saved-address-a2')),
        matching: find.byTooltip('Delete address')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fake.calls.where((c) => c.startsWith('DELETE')), isEmpty);

    await tester.tap(find.descendant(
        of: find.byKey(const Key('saved-address-a2')),
        matching: find.byTooltip('Delete address')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('DELETE /users/me/addresses/a2'));
    expect(find.text('OFFICE'), findsNothing);

    await tester.tap(find.byTooltip('Delete address'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Could not delete it: keep at least one address'), findsOneWidget);
  });

  testWidgets('says so when the addresses cannot load', (tester) async {
    installFakeApi({'GET /users/me/addresses': (_) => const FakeError(500, 'down')});
    await pump(tester);
    expect(find.textContaining('Could not load your addresses'), findsOneWidget);
  });

  testWidgets('the request detail shows where the job is', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    installFakeApi({});
    final r = Requirement.fromJson({
      'id': 'r1',
      'subServiceId': 's1',
      'title': 'Fan',
      'description': 'Fix the fan',
      'status': 'SENT',
      'address': address('a1', 'Home', 'Edappally'),
    });
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => openRequestDetail(context, r),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
        find.textContaining('Home: 12B, Palm Grove, Changampuzha Nagar, Edappally'),
        findsOneWidget);
  });

  group('Home address sheet', () {
    Future<List<SavedLocation?>> open(WidgetTester tester,
        {SavedLocation? current}) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final results = <SavedLocation?>[];
      await tester.pumpWidget(MaterialApp(
        theme: OneHubTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  results.add(await chooseHomeAddress(context, current)),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    testWidgets('marks the address Home is set to and returns the one picked',
        (tester) async {
      installFakeApi({
        'GET /users/me/addresses': (_) =>
            [address('a1', 'Home', 'Edappally'), address('a2', 'Office', 'Kakkanad')],
      });
      final results = await open(tester,
          current: const SavedLocation(
              city: 'Edappally', latitude: 10.0261, longitude: 76.3125));

      expect(find.byIcon(OneHubIcons.successCheck), findsNWidgets(2),
          reason: 'both test addresses share one position');
      await tester.tap(find.byKey(const Key('home-address-a2')));
      await tester.pumpAndSettle();

      expect(results.single!.city, 'Kakkanad');
    });

    testWidgets('Add new address opens the form and returns the saved one',
        (tester) async {
      installFakeApi({
        'GET /users/me/addresses': (_) => [address('a1', 'Home', 'Edappally')],
        'POST /users/me/addresses': (_) => address('a3', 'Other', 'Aluva'),
      });
      final results = await open(tester);

      await tester.tap(find.byKey(const Key('home-add-address')));
      await tester.pumpAndSettle();
      expect(find.byType(AddressFormScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(results, [null], reason: 'backing out of the form sets nothing');
    });

    testWidgets('says so when the addresses cannot load', (tester) async {
      installFakeApi({'GET /users/me/addresses': (_) => const FakeError(500)});
      await open(tester);
      expect(find.text('Could not load your addresses.'), findsOneWidget);
      expect(find.byKey(const Key('home-add-address')), findsOneWidget);
    });
  });
}
