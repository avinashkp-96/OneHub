import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  group('ServiceCategory.fromJson', () {
    test('parses a full category', () {
      final category = ServiceCategory.fromJson({
        'id': 'cat_1',
        'name': 'Electrician',
        'iconUrl': 'https://example.com/icon.png',
        'description': 'Wiring and repairs',
      });
      expect(category.id, 'cat_1');
      expect(category.name, 'Electrician');
      expect(category.iconUrl, 'https://example.com/icon.png');
    });

    test('tolerates a missing optional iconUrl/description', () {
      final category = ServiceCategory.fromJson({'id': 'cat_2', 'name': 'Plumber'});
      expect(category.iconUrl, isNull);
      expect(category.description, isNull);
    });
  });

  group('SubService.fromJson', () {
    test('parses suggested price range as doubles', () {
      final subService = SubService.fromJson({
        'id': 'sub_1',
        'categoryId': 'cat_1',
        'name': 'Switchboard Repair',
        'suggestedMinPrice': 200,
        'suggestedMaxPrice': 450,
      });
      expect(subService.suggestedMinPrice, 200.0);
      expect(subService.suggestedMaxPrice, 450.0);
    });

    test('leaves suggested price range null when absent', () {
      final subService = SubService.fromJson({'id': 'sub_2', 'categoryId': 'cat_1', 'name': 'Tap Installation'});
      expect(subService.suggestedMinPrice, isNull);
      expect(subService.suggestedMaxPrice, isNull);
    });
  });
}
