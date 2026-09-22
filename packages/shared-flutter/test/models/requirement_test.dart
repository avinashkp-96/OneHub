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
  });
}
