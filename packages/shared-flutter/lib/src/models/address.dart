/// A customer's saved address, or the copy of one a request keeps: what a
/// provider needs to find the place, plus the map position distances are
/// measured from. Mirrors the API's Address model and AddressDto.
class JobAddress {
  /// Null for the copy on a request.
  final String? id;
  final String label;
  final String house;
  final String street;
  final String? landmark;
  final String pincode;

  /// The area's name, e.g. "Edappally".
  final String city;
  final double latitude;
  final double longitude;

  const JobAddress({
    this.id,
    this.label = 'Home',
    required this.house,
    required this.street,
    this.landmark,
    required this.pincode,
    required this.city,
    required this.latitude,
    required this.longitude,
  });

  /// Null when [json] is not an address with a map position.
  static JobAddress? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final lat = json['latitude'];
    final lng = json['longitude'];
    if (lat is! num || lng is! num) return null;
    final landmark = (json['landmark'] as String?)?.trim();
    return JobAddress(
      id: json['id'] as String?,
      label: json['label'] as String? ?? 'Home',
      house: json['house'] as String? ?? '',
      street: json['street'] as String? ?? '',
      landmark: landmark == null || landmark.isEmpty ? null : landmark,
      pincode: json['pincode'] as String? ?? '',
      city: json['city'] as String? ?? '',
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
    );
  }

  /// The body for POST /users/me/addresses and the signup address.
  Map<String, Object> toJson() => {
        'label': label,
        'house': house,
        'street': street,
        if (landmark != null) 'landmark': landmark!,
        'pincode': pincode,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
      };

  /// "12B, Palm Grove", "Changampuzha Nagar, Edappally", "Near the church",
  /// "PIN 682024": the lines a provider reads to find the place.
  List<String> get lines => [
        house,
        [street, if (!street.contains(city)) city]
            .where((s) => s.isNotEmpty)
            .join(', '),
        if (landmark != null) 'Near $landmark',
        if (pincode.isNotEmpty) 'PIN $pincode',
      ].where((l) => l.isNotEmpty).toList();

  /// [lines] on one line, for lists.
  String get oneLine => lines.join(', ');
}
