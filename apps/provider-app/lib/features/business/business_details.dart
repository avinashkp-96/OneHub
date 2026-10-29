// The provider's own business details as returned by GET /providers/me
// (docx 5.2): one service category, the services offered under it,
// experience and coverage radius.

class OfferedService {
  final String id;
  final String name;
  const OfferedService(this.id, this.name);
}

class BusinessDetails {
  final String? categoryId;
  final String? categoryName;
  final List<OfferedService> services;
  final int? yearsExperience;
  final double coverageRadiusKm;

  const BusinessDetails({
    required this.categoryId,
    required this.categoryName,
    required this.services,
    required this.yearsExperience,
    required this.coverageRadiusKm,
  });

  factory BusinessDetails.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    return BusinessDetails(
      categoryId: category?['id'] as String?,
      categoryName: category?['name'] as String?,
      services: [
        for (final s in (json['subServices'] as List? ?? const []))
          OfferedService((s as Map<String, dynamic>)['id'] as String,
              s['name'] as String),
      ],
      yearsExperience: (json['yearsExperience'] as num?)?.toInt(),
      coverageRadiusKm: (json['coverageRadiusKm'] as num).toDouble(),
    );
  }

  String get experienceLabel => switch (yearsExperience) {
        null => 'Not set',
        1 => '1 year',
        final y => '$y years',
      };

  String get coverageLabel => '${formatKm(coverageRadiusKm)} km radius';

  String get servicesLabel =>
      services.length == 1 ? '1 service' : '${services.length} services';
}

/// "10" for whole numbers, "7.5" otherwise.
String formatKm(double km) =>
    km == km.roundToDouble() ? km.toInt().toString() : km.toString();
