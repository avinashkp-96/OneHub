import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';

// Where a provider stands on one request, and the job detail page both
// Incoming requests and Active jobs open: the request card, a progress
// timeline, then the customer, location, the provider's own price, the
// preferred date and photo count, with an optional action at the bottom.

/// Where this provider is with a request, from their own answer and bid
/// rather than the request's overall status.
enum IncomingStage {
  /// No price sent yet: Reject or Send price.
  newRequest,

  /// Price sent, waiting for the customer.
  bidSent,
  selected,
  notSelected,
  completed,

  /// Another provider was chosen, or it was cancelled or expired, before
  /// this provider sent a price.
  closed,
}

IncomingStage incomingStageOf(Requirement r) {
  final bid = r.bids.isEmpty ? null : r.bids.first;
  final decided = r.status == RequestStatus.confirmed ||
      r.status == RequestStatus.completed;
  if (bid != null) {
    if (bid.confirmed) {
      return r.status == RequestStatus.completed
          ? IncomingStage.completed
          : IncomingStage.selected;
    }
    return decided ? IncomingStage.notSelected : IncomingStage.bidSent;
  }
  if (decided ||
      r.status == RequestStatus.cancelled ||
      r.status == RequestStatus.expired) {
    return IncomingStage.closed;
  }
  // A provider who accepted under the old two-step flow but never priced it
  // is treated as new: they still need to send a price.
  return IncomingStage.newRequest;
}

String incomingStageLabel(IncomingStage stage) => switch (stage) {
      IncomingStage.newRequest => 'NEW',
      IncomingStage.bidSent => 'BID SENT',
      IncomingStage.selected => 'SELECTED',
      IncomingStage.notSelected => 'NOT SELECTED',
      IncomingStage.completed => 'COMPLETED',
      IncomingStage.closed => 'CLOSED',
    };

Color incomingStageColor(BuildContext context, IncomingStage stage) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final muted =
      dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
  return switch (stage) {
    IncomingStage.newRequest => context.statusWarning,
    IncomingStage.bidSent => OneHubColors.primaryDark,
    IncomingStage.selected || IncomingStage.completed => context.statusSuccess,
    IncomingStage.notSelected || IncomingStage.closed => muted,
  };
}

/// This provider's price on the request, "₹350 – ₹600", using the refined
/// range once they have updated it. Null before they send one.
String? bidRangeLabel(Requirement r) {
  if (r.bids.isEmpty) return null;
  final b = r.bids.first;
  String rupees(double v) => '₹${v.round()}';
  return '${rupees(b.refinedMinPrice ?? b.initialMinPrice)} – '
      '${rupees(b.refinedMaxPrice ?? b.initialMaxPrice)}';
}

/// Send price → customer chooses → job in progress → completed, as far as
/// [stage] has got. Not selected and closed end the timeline early.
List<TimelineStep> jobTimeline(IncomingStage stage) {
  TimelineState at(int step) {
    final reached = switch (stage) {
      IncomingStage.newRequest => 0,
      IncomingStage.bidSent => 1,
      IncomingStage.selected => 2,
      IncomingStage.completed => 4,
      IncomingStage.notSelected => 2,
      IncomingStage.closed => 0,
    };
    if (step < reached) return TimelineState.done;
    return step == reached ? TimelineState.current : TimelineState.todo;
  }

  // Closed before this provider sent a price: nothing else happened.
  if (stage == IncomingStage.closed) {
    return const [TimelineStep('Closed to new prices', TimelineState.current)];
  }
  return [
    TimelineStep('Send your price', at(0)),
    TimelineStep('Customer chooses a provider', at(1)),
    if (stage == IncomingStage.notSelected)
      const TimelineStep('Not selected', TimelineState.current)
    else ...[
      TimelineStep('Job in progress', at(2)),
      TimelineStep('Completed', at(3)),
    ],
  ];
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Opens the job detail for [job]. [statusLabel] and [statusColor] come from
/// the calling list so the badge matches its card; [action] is the button
/// row at the bottom, if any.
Future<void> openJobDetail(
  BuildContext context,
  Requirement job, {
  required String statusLabel,
  required Color statusColor,
  required List<TimelineStep> steps,
  Widget? action,
}) {
  final distance = job.distanceKm;
  final place = [
    if (job.customerPlace != null) job.customerPlace!,
    if (distance != null) '${distance.toStringAsFixed(1)} km away',
  ].join(' · ');
  final bid = bidRangeLabel(job);
  final preferred = job.preferredAt;

  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => RequestDetailScreen(
      heading: 'Job',
      postedAt: job.createdAt,
      title: job.title,
      description: job.description,
      statusLabel: statusLabel,
      statusColor: statusColor,
      steps: steps,
      facts: [
        if (job.customerName != null) DetailFact('Customer', job.customerName!),
        if (place.isNotEmpty) DetailFact('Location', place),
        if (bid != null) DetailFact('Your bid', bid),
        if (preferred != null)
          DetailFact('Preferred date',
              '${preferred.day} ${_months[preferred.month - 1]} ${preferred.year}'),
        DetailFact('Photos', '${job.photoUrls.length}'),
      ],
      action: action,
    ),
  ));
}
