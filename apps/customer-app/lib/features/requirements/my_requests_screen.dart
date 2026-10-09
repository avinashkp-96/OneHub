import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import 'bid_list_screen.dart';
import 'rating_screen.dart';

// docx 4.4 "My Requests — Status View" + 4.5 "Booking / Request History"
// combined into one list, since both read from the same /requirements/mine
// endpoint and differ only in which statuses they'd normally filter to.
// Restyled to match the current OneHub design system (no new reference —
// applied on request): PageGlow behind the page, a back-only AppBar plus an
// in-body heading, and request rows as bordered cards with a TintedBadge
// status pill, matching the tile pattern used for provider/bid/sub-service
// rows elsewhere in this feature. The status label/color mapping mirrors
// DashboardScreen's _ActiveRequestCard, since both read the same
// RequestStatus enum for the same underlying data — this screen just
// covers the full history (including terminal statuses like Completed or
// Expired) rather than DashboardScreen's in-progress-only preview, so it
// uses a single badge instead of that card's 4-step tracker, which has no
// sensible position for a terminal status.
String requestStatusLabel(Requirement r) => switch (r.status) {
      RequestStatus.sent => 'SENT',
      RequestStatus.accepted => 'ACCEPTED',
      RequestStatus.rejected => 'REJECTED',
      RequestStatus.bidReceived => '${r.bids.length} BIDS',
      RequestStatus.confirmed => 'CONFIRMED',
      RequestStatus.completed => 'COMPLETED',
      RequestStatus.cancelled => 'CANCELLED',
      RequestStatus.expired => 'EXPIRED',
    };

Color requestStatusColor(BuildContext context, RequestStatus status) =>
    switch (status) {
      RequestStatus.confirmed ||
      RequestStatus.completed =>
        context.statusSuccess,
      RequestStatus.bidReceived => context.statusWarning,
      RequestStatus.rejected ||
      RequestStatus.cancelled ||
      RequestStatus.expired =>
        context.statusDanger,
      _ => OneHubColors.primary,
    };

// The happy path is Sent → Accepted → Bids received → Confirmed → Completed.
// A request that ended any other way (rejected, cancelled, expired) shows
// Sent followed by how it ended, since the rest never happened.
List<TimelineStep> requestTimeline(RequestStatus status) {
  const path = [
    ('Sent', RequestStatus.sent),
    ('Accepted by a provider', RequestStatus.accepted),
    ('Bids received', RequestStatus.bidReceived),
    ('Provider confirmed', RequestStatus.confirmed),
    ('Job completed', RequestStatus.completed),
  ];
  final index = path.indexWhere((p) => p.$2 == status);
  if (index == -1) {
    final ended = switch (status) {
      RequestStatus.rejected => 'Rejected',
      RequestStatus.cancelled => 'Cancelled',
      _ => 'Expired',
    };
    return [
      const TimelineStep('Sent', TimelineState.done),
      TimelineStep(ended, TimelineState.current),
    ];
  }
  return [
    for (var i = 0; i < path.length; i++)
      TimelineStep(
          path[i].$1,
          i < index
              ? TimelineState.done
              : i == index
                  ? (status == RequestStatus.completed
                      ? TimelineState.done
                      : TimelineState.current)
                  : TimelineState.todo),
  ];
}

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  List<Requirement> _requirements = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await api.get('/requirements/mine') as List;
      if (!mounted) return;
      setState(() {
        _requirements = json
            .map((r) => Requirement.fromJson(r as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your requests: $e';
        _loading = false;
      });
    }
  }

  Future<void> _open(Requirement r) async {
    if (r.status == RequestStatus.completed) {
      Bid? confirmedBid;
      for (final b in r.bids) {
        if (b.confirmed) {
          confirmedBid = b;
          break;
        }
      }
      if (confirmedBid == null) {
        return; // shouldn't happen, but nothing sane to open
      }
      final providerId = confirmedBid
          .providerId; // captured as final so the closure below can use it
      final alreadyRated = await api.get('/ratings/requirement/${r.id}');
      if (!mounted) return;
      if (alreadyRated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You've already rated this job.")));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) =>
                RatingScreen(requirementId: r.id, providerId: providerId)),
      );
      _load();
      return;
    }
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BidListScreen(requirementId: r.id)));
    _load();
  }

  // Tapping a row opens the detail view first; the old tap behaviour (bids
  // or rating) is now its action button.
  Future<void> _openDetail(Requirement r) async {
    final String? actionLabel = r.status == RequestStatus.completed
        ? (r.bids.any((b) => b.confirmed) ? 'Rate provider' : null)
        : switch (r.status) {
            RequestStatus.accepted ||
            RequestStatus.bidReceived ||
            RequestStatus.confirmed =>
              'View bids',
            _ => null,
          };

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RequestDetailScreen(
        heading: 'Request',
        description: r.description,
        statusLabel: requestStatusLabel(r),
        statusColor: requestStatusColor(context, r.status),
        steps: requestTimeline(r.status),
        facts: [
          DetailFact('Bids', '${r.bids.length}'),
          DetailFact('Photos', '${r.photoUrls.length}'),
        ],
        action: actionLabel == null
            ? null
            : PrimaryCta(onPressed: () => _open(r), child: Text(actionLabel)),
      ),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: OneHubTheme.pageMargin, vertical: 8),
              children: [
                Text('My requests',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 26)),
                const SizedBox(height: 8),
                Text(
                  'Everything you\'ve posted, and where it stands.',
                  style: OneHubTextStyles.bodyText(textSecondary),
                ),
                const SizedBox(height: OneHubTheme.sectionGap),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!,
                        style: TextStyle(color: context.statusDanger)),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_requirements.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      "You haven't posted any requirements yet.",
                      style: OneHubTextStyles.bodyText(context.statusWarning),
                    ),
                  )
                else
                  for (final r in _requirements)
                    _RequestTile(requirement: r, onTap: () => _openDetail(r)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final Requirement requirement;
  final VoidCallback onTap;
  const _RequestTile({required this.requirement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final statusColor = requestStatusColor(context, requirement.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requirement.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OneHubTextStyles.bodyText(textPrimary)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TintedBadge(
                        label: requestStatusLabel(requirement),
                        color: statusColor),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(OneHubIcons.chevronRight, size: 18, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
