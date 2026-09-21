// Mirrors GET /providers?subServiceId=... response shape — docx 4.2/4.3.
class ProviderSummary {
  final String id;
  final String name;
  final double averageRating;
  final bool certified;

  const ProviderSummary({
    required this.id,
    required this.name,
    required this.averageRating,
    required this.certified,
  });

  factory ProviderSummary.fromJson(Map<String, dynamic> json) => ProviderSummary(
        id: json['id'] as String,
        name: (json['businessName'] as String?) ?? (json['user']?['fullName'] as String? ?? 'Provider'),
        averageRating: (json['averageRating'] as num).toDouble(),
        certified: json['certified'] as bool,
      );
}
