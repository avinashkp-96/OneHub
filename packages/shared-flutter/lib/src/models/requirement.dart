// Mirrors services/api Prisma model `Requirement` / `Bid` — docx sections 4.3-4.5, 5.3-5.4.
enum RequestStatus { sent, accepted, rejected, bidReceived, confirmed, completed, cancelled, expired }

const _requestStatusByApiValue = {
  'SENT': RequestStatus.sent,
  'ACCEPTED': RequestStatus.accepted,
  'REJECTED': RequestStatus.rejected,
  'BID_RECEIVED': RequestStatus.bidReceived,
  'CONFIRMED': RequestStatus.confirmed,
  'COMPLETED': RequestStatus.completed,
  'CANCELLED': RequestStatus.cancelled,
  'EXPIRED': RequestStatus.expired,
};

RequestStatus requestStatusFromJson(String value) =>
    _requestStatusByApiValue[value] ?? RequestStatus.sent;

class Requirement {
  final String id;
  final String subServiceId;
  final String description;
  final List<String> photoUrls;
  final RequestStatus status;
  // On /requirements/incoming this is filtered to the requesting provider's
  // own bid (0 or 1 entries) — use it to tell "my bid was confirmed" apart
  // from "a different provider on this request was confirmed" (docx 5.6).
  // On /requirements/mine (customer side) this holds every bid received.
  final List<Bid> bids;

  const Requirement({
    required this.id,
    required this.subServiceId,
    required this.description,
    required this.photoUrls,
    required this.status,
    this.bids = const [],
  });

  factory Requirement.fromJson(Map<String, dynamic> json) => Requirement(
        id: json['id'] as String,
        subServiceId: json['subServiceId'] as String,
        description: json['description'] as String,
        photoUrls: (json['photoUrls'] as List?)?.cast<String>() ?? const [],
        status: requestStatusFromJson(json['status'] as String),
        bids: (json['bids'] as List?)?.map((b) => Bid.fromJson(b as Map<String, dynamic>)).toList() ?? const [],
      );
}

class Bid {
  final String id;
  final String providerId;
  final double initialMinPrice;
  final double initialMaxPrice;
  final double? refinedMinPrice;
  final double? refinedMaxPrice;
  final bool contactUnlocked;
  final bool confirmed;

  const Bid({
    required this.id,
    required this.providerId,
    required this.initialMinPrice,
    required this.initialMaxPrice,
    this.refinedMinPrice,
    this.refinedMaxPrice,
    required this.contactUnlocked,
    required this.confirmed,
  });

  factory Bid.fromJson(Map<String, dynamic> json) => Bid(
        id: json['id'] as String,
        providerId: json['providerId'] as String,
        initialMinPrice: (json['initialMinPrice'] as num).toDouble(),
        initialMaxPrice: (json['initialMaxPrice'] as num).toDouble(),
        refinedMinPrice: (json['refinedMinPrice'] as num?)?.toDouble(),
        refinedMaxPrice: (json['refinedMaxPrice'] as num?)?.toDouble(),
        contactUnlocked: json['contactUnlocked'] as bool,
        confirmed: json['confirmed'] as bool,
      );
}
