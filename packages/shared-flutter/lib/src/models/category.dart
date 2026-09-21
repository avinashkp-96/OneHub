// Mirrors services/api Prisma model `Category` / `SubService` — docx section 3.
class ServiceCategory {
  final String id;
  final String name;
  final String? iconUrl;
  final String? description;

  const ServiceCategory({required this.id, required this.name, this.iconUrl, this.description});

  factory ServiceCategory.fromJson(Map<String, dynamic> json) => ServiceCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        iconUrl: json['iconUrl'] as String?,
        description: json['description'] as String?,
      );
}

class SubService {
  final String id;
  final String categoryId;
  final String name;
  final double? suggestedMinPrice;
  final double? suggestedMaxPrice;

  const SubService({
    required this.id,
    required this.categoryId,
    required this.name,
    this.suggestedMinPrice,
    this.suggestedMaxPrice,
  });

  factory SubService.fromJson(Map<String, dynamic> json) => SubService(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        name: json['name'] as String,
        suggestedMinPrice: (json['suggestedMinPrice'] as num?)?.toDouble(),
        suggestedMaxPrice: (json['suggestedMaxPrice'] as num?)?.toDouble(),
      );
}
