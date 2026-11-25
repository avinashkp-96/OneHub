import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  final json = {
    'id': 'a1',
    'label': 'Home',
    'house': '12B, Palm Grove',
    'street': 'Changampuzha Nagar',
    'landmark': 'Edappally Church',
    'pincode': '682024',
    'city': 'Edappally',
    'latitude': 10.0261,
    'longitude': 76.3125,
  };

  group('JobAddress', () {
    test('reads an address and lists the lines a provider needs', () {
      final a = JobAddress.tryParse(json)!;
      expect(a.id, 'a1');
      expect(a.lines, [
        '12B, Palm Grove',
        'Changampuzha Nagar, Edappally',
        'Near Edappally Church',
        'PIN 682024',
      ]);
      expect(a.oneLine,
          '12B, Palm Grove, Changampuzha Nagar, Edappally, Near Edappally Church, PIN 682024');
    });

    test('does not repeat an area already in the street, and skips a blank landmark', () {
      final a = JobAddress.tryParse(
          {...json, 'street': 'MG Road, Edappally', 'landmark': '  '})!;
      expect(a.lines, ['12B, Palm Grove', 'MG Road, Edappally', 'PIN 682024']);
      expect(a.toJson().containsKey('landmark'), isFalse);
    });

    test('is null without a map position, or for anything not a map', () {
      expect(JobAddress.tryParse({...json, 'latitude': null}), isNull);
      expect(JobAddress.tryParse(null), isNull);
      expect(JobAddress.tryParse('12B'), isNull);
    });

    test('the body to save leaves out the id', () {
      final body = JobAddress.tryParse(json)!.toJson();
      expect(body, {
        'label': 'Home',
        'house': '12B, Palm Grove',
        'street': 'Changampuzha Nagar',
        'landmark': 'Edappally Church',
        'pincode': '682024',
        'city': 'Edappally',
        'latitude': 10.0261,
        'longitude': 76.3125,
      });
    });

    test('a request carries its job address when the API sends one', () {
      final base = {
        'id': 'r1',
        'subServiceId': 's1',
        'description': 'Fan',
        'status': 'CONFIRMED',
      };
      expect(Requirement.fromJson({...base, 'address': json}).address?.city,
          'Edappally');
      expect(Requirement.fromJson({...base, 'address': null}).address, isNull);
    });
  });

  testWidgets('the Terms and Privacy links open the Terms & privacy page',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: const Scaffold(
          body: TermsAgreementText(
              textColor: Colors.white, linkColor: Colors.blue)),
    ));

    expect(find.text('Terms & Conditions'), findsOneWidget);
    await tester.tap(find.byKey(const Key('terms-link')));
    await tester.pumpAndSettle();
    expect(find.byType(InfoScreen), findsOneWidget);
    expect(find.text('Terms & privacy'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('privacy-link')));
    await tester.pumpAndSettle();
    expect(find.byType(InfoScreen), findsOneWidget);
  });

  testWidgets('without privacy only the Terms link shows', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: TermsAgreementText(
              lead: 'I accept the ',
              privacy: false,
              textColor: Colors.white,
              linkColor: Colors.blue)),
    ));
    expect(find.byKey(const Key('privacy-link')), findsNothing);
    expect(find.byKey(const Key('terms-link')), findsOneWidget);
  });
}
