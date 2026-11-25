import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_provider/features/business/business_details.dart';

void main() {
  final base = {
    'coverageRadiusKm': 10,
    'subServices': [
      {'id': 's1', 'name': 'Fan Installation', 'categoryId': 'c1'},
      {'id': 's5', 'name': 'Leak Repair', 'categoryId': 'c2'},
    ],
  };

  test('reads every category and each service\'s category', () {
    final d = BusinessDetails.fromJson({
      ...base,
      'category': {'id': 'c1', 'name': 'Electrician'},
      'categories': [
        {'id': 'c1', 'name': 'Electrician'},
        {'id': 'c2', 'name': 'Plumber'},
      ],
    });
    expect(d.categories.map((c) => c.id), ['c1', 'c2']);
    expect(d.categoriesLabel, 'Electrician, Plumber');
    expect(d.services.last.categoryId, 'c2');
  });

  test('an older API with one category, or none, still reads', () {
    final old = BusinessDetails.fromJson({
      ...base,
      'category': {'id': 'c1', 'name': 'Electrician'},
    });
    expect(old.categoriesLabel, 'Electrician');

    final none = BusinessDetails.fromJson({'coverageRadiusKm': 5});
    expect(none.categories, isEmpty);
    expect(none.categoriesLabel, 'Not set');
  });
}
