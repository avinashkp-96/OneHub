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

  // Account and documents (docx 5.2). The API never sends the ID proof link
  // or raw bank details back: only whether an ID is on file, whether a new
  // one awaits review, and the payout details masked.
  final String businessName;
  final String mobile;
  final String email;
  final String? profilePhotoUrl;
  final String status;
  final bool idProofOnFile;
  final bool idProofNeedsReview;
  final String? bankOrUpiMasked;

  const BusinessDetails({
    required this.categoryId,
    required this.categoryName,
    required this.services,
    required this.yearsExperience,
    required this.coverageRadiusKm,
    this.businessName = '',
    this.mobile = '',
    this.email = '',
    this.profilePhotoUrl,
    this.status = 'ACTIVE',
    this.idProofOnFile = false,
    this.idProofNeedsReview = false,
    this.bankOrUpiMasked,
  });

  factory BusinessDetails.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    return BusinessDetails(
      categoryId: category?['id'] as String?,
      categoryName: category?['name'] as String?,
      services: [
        for (final s in (json['subServices'] as List? ?? const []))
          OfferedService(
              (s as Map<String, dynamic>)['id'] as String, s['name'] as String),
      ],
      yearsExperience: (json['yearsExperience'] as num?)?.toInt(),
      coverageRadiusKm: (json['coverageRadiusKm'] as num).toDouble(),
      businessName: json['businessName'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      idProofOnFile: json['idProofOnFile'] as bool? ?? false,
      idProofNeedsReview: json['idProofNeedsReview'] as bool? ?? false,
      bankOrUpiMasked: json['bankOrUpiMasked'] as String?,
    );
  }

  /// "+91 90000 00002" for a 10-digit mobile, otherwise as stored.
  String get phoneLabel => mobile.length == 10
      ? '+91 ${mobile.substring(0, 5)} ${mobile.substring(5)}'
      : mobile;

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
