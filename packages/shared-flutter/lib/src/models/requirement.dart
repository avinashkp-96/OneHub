import 'category.dart';

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

/// Longest request title the API accepts (REQUIREMENT_TITLE_MAX in
/// services/api post-requirement.dto.ts).
const requestTitleMaxLength = 60;

RequestStatus requestStatusFromJson(String value) =>
    _requestStatusByApiValue[value] ?? RequestStatus.sent;

class Requirement {
  final String id;
  final String subServiceId;
  // Short headline shown above the description. Empty only for a response
  // that predates titles; screens then fall back to the description.
  final String title;
  final String description;
  final List<String> photoUrls;
  final RequestStatus status;
  // On /requirements/incoming this is filtered to the requesting provider's
  // own bid (0 or 1 entries) — use it to tell "my bid was confirmed" apart
  // from "a different provider on this request was confirmed" (docx 5.6).
  // On /requirements/mine (customer side) this holds every bid received.
  final List<Bid> bids;
  // Customer side only: each provider the request was sent to and how they
  // answered (docx 4.4). Empty on the provider side.
  final List<TargetedProvider> targetedProviders;
  // Provider side only (/requirements/incoming): who posted it, their city
  // and the straight-line distance from the provider, so the provider can
  // decide before accepting. Null when unknown or on the customer side.
  final String? customerName;
  final String? customerPlace;
  final double? distanceKm;
  // Provider side only: this provider's own answer (sent = not answered yet,
  // accepted or rejected). [status] can reflect another provider on a
  // multi-provider request. Null on the customer side.
  final RequestStatus? myResponse;
  // When the customer posted it. Null if the response leaves it out.
  final DateTime? createdAt;
  // When the customer would like the job done, if they picked a date.
  final DateTime? preferredAt;
  // The sub-service it was posted under, with its typical price range. Null
  // when the response does not include it.
  final SubService? subService;

  const Requirement({
    required this.id,
    required this.subServiceId,
    this.title = '',
    required this.description,
    required this.photoUrls,
    required this.status,
    this.bids = const [],
    this.targetedProviders = const [],
    this.customerName,
    this.customerPlace,
    this.distanceKm,
    this.myResponse,
    this.createdAt,
    this.preferredAt,
    this.subService,
  });

  factory Requirement.fromJson(Map<String, dynamic> json) => Requirement(
        id: json['id'] as String,
        subServiceId: json['subServiceId'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String,
        photoUrls: (json['photoUrls'] as List?)?.cast<String>() ?? const [],
        status: requestStatusFromJson(json['status'] as String),
        bids: (json['bids'] as List?)?.map((b) => Bid.fromJson(b as Map<String, dynamic>)).toList() ?? const [],
        targetedProviders: (json['targetedProviders'] as List?)
                ?.map((t) => t as Map<String, dynamic>)
                .where((t) => t['providerName'] != null)
                .map(TargetedProvider.fromJson)
                .toList() ??
            const [],
        customerName: json['customerName'] as String?,
        customerPlace: json['customerPlace'] as String?,
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        myResponse: json['myResponse'] == null
            ? null
            : requestStatusFromJson(json['myResponse'] as String),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String).toLocal(),
        preferredAt: json['preferredAt'] == null
            ? null
            : DateTime.parse(json['preferredAt'] as String).toLocal(),
        subService: json['subService'] is Map<String, dynamic>
            ? SubService.fromJson(json['subService'] as Map<String, dynamic>)
            : null,
      );

  /// The title, or the description when there is no title.
  String get heading => title.isNotEmpty ? title : description;
}

/// One provider a request was sent to, with their own answer: still pending
/// (sent), accepted or rejected.
class TargetedProvider {
  final String providerId;
  final String providerName;
  final RequestStatus status;

  const TargetedProvider({
    required this.providerId,
    required this.providerName,
    required this.status,
  });

  factory TargetedProvider.fromJson(Map<String, dynamic> json) => TargetedProvider(
        providerId: json['providerId'] as String,
        providerName: json['providerName'] as String,
        status: requestStatusFromJson(json['status'] as String),
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
