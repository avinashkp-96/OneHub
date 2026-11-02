import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  group('Requirement.fromJson', () {
    test('defaults bids to empty when the field is absent', () {
      final requirement = Requirement.fromJson({
        'id': 'req_1',
        'subServiceId': 'sub_1',
        'description': 'Fix a leaking tap',
        'status': 'SENT',
      });
      expect(requirement.bids, isEmpty);
    });

    test('parses bids when present, e.g. the provider-filtered list from /requirements/incoming', () {
      final requirement = Requirement.fromJson({
        'id': 'req_1',
        'subServiceId': 'sub_1',
        'description': 'Fix a leaking tap',
        'status': 'CONFIRMED',
        'bids': [
          {
            'id': 'bid_1',
            'providerId': 'provider_1',
            'initialMinPrice': 200,
            'initialMaxPrice': 400,
            'contactUnlocked': true,
            'confirmed': true,
          },
        ],
      });
      expect(requirement.bids, hasLength(1));
      expect(requirement.bids.single.confirmed, isTrue);
      expect(requirement.bids.single.providerId, 'provider_1');
    });

    test('falls back to RequestStatus.sent for an unrecognized status value', () {
      final requirement = Requirement.fromJson({
        'id': 'req_1',
        'subServiceId': 'sub_1',
        'description': 'Fix a leaking tap',
        'status': 'SOMETHING_NEW',
      });
      expect(requirement.status, RequestStatus.sent);
    });

    test('parses the customer details sent with /requirements/incoming', () {
      final requirement = Requirement.fromJson({
        'id': 'req_1',
        'subServiceId': 'sub_1',
        'description': 'Fix a leaking tap',
        'status': 'SENT',
        'customerName': 'Meera Nair',
        'customerPlace': 'Kochi',
        'distanceKm': 7,
      });
      expect(requirement.customerName, 'Meera Nair');
      expect(requirement.customerPlace, 'Kochi');
      expect(requirement.distanceKm, 7.0);
    });

    test('parses the title and uses it as the heading', () {
      final requirement = Requirement.fromJson({
        'id': 'req_1',
        'subServiceId': 'sub_1',
        'title': 'Leaking tap',
        'description': 'Fix a leaking tap',
        'status': 'SENT',
      });
      expect(requirement.title, 'Leaking tap');
      expect(requirement.heading, 'Leaking tap');
    });

    test('falls back to the description when there is no title', () {
      final requirement = Requirement.fromJson({
        'id': 'req_1',
        'subServiceId': 'sub_1',
        'description': 'Fix a leaking tap',
        'status': 'SENT',
      });
      expect(requirement.title, '');
      expect(requirement.heading, 'Fix a leaking tap');
    });

    test('parses the provider\'s own answer, null when absent', () {
      Requirement parse(Map<String, dynamic> extra) => Requirement.fromJson({
            'id': 'req_1',
            'subServiceId': 'sub_1',
            'description': 'Fix a leaking tap',
            'status': 'ACCEPTED',
            ...extra,
          });
      expect(parse({'myResponse': 'REJECTED'}).myResponse,
          RequestStatus.rejected);
      expect(parse({}).myResponse, isNull);
    });

    test('parses the preferred date, null when absent', () {
      Requirement parse(Map<String, dynamic> extra) => Requirement.fromJson({
            'id': 'req_1',
            'subServiceId': 'sub_1',
            'description': 'Fix a leaking tap',
            'status': 'SENT',
            ...extra,
          });
      expect(parse({'preferredAt': '2026-11-05T10:00:00.000Z'}).preferredAt,
          DateTime.utc(2026, 11, 5, 10).toLocal());
      expect(parse({'preferredAt': null}).preferredAt, isNull);
    });

    test('leaves the customer details null when absent', () {
      final requirement = Requirement.fromJson({
        'id': 'req_1',
        'subServiceId': 'sub_1',
        'description': 'Fix a leaking tap',
        'status': 'SENT',
        'distanceKm': null,
      });
      expect(requirement.customerName, isNull);
      expect(requirement.customerPlace, isNull);
      expect(requirement.distanceKm, isNull);
    });
  });
}
