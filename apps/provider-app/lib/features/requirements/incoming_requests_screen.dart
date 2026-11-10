import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../bids/price_range_screen.dart';
import 'job_detail.dart';

// docx 5.3 — Incoming Requests. Send price opens the Price Range screen (5.4).
// Restyled to match the customer app's list screens (no new reference —
// applied on request): PageGlow and a page title in the AppBar.
// A new request offers Reject or Send price. Sending a price is how a
// provider accepts (there is no separate accept step); after that there are
// no buttons, and the customer chooses among the prices.
// The label comes from this provider's own answer and bid (incomingStageOf),
// not the request's overall status. Requests they rejected are hidden.
// Each request is the shared RequestCard (status, posted time,
// title, description, then customer, location and distance, and photos), so
// the provider can decide before sending a price.
// Takes an optional [client], like SignupScreen, so tests can use a fake API.
class IncomingRequestsScreen extends StatefulWidget {
  final ApiClient? client;

  /// True when shown as the Requests tab under the bottom bar: no back arrow.
  final bool asTab;
  const IncomingRequestsScreen({super.key, this.client, this.asTab = false});

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen> {
  List<Requirement> _requests = [];
  bool _loading = true;
  String? _error;

  ApiClient get _api => widget.client ?? api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await _api.get('/requirements/incoming') as List;
      if (!mounted) return;
      setState(() {
        // Requests this provider turned down drop off the list.
        _requests = json
            .map((r) => Requirement.fromJson(r as Map<String, dynamic>))
            .where((r) => r.myResponse != RequestStatus.rejected)
            .toList();
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load incoming requests: $e';
        _loading = false;
      });
    }
  }

  // Sending a price is how a provider accepts a request; there is no separate
  // accept step. The customer then chooses among the prices they get.
  Future<void> _sendPrice(Requirement r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              PriceRangeScreen(requirementId: r.id, client: widget.client)),
    );
    if (mounted) _load();
  }

  Future<void> _openDetail(Requirement r) => openIncomingDetail(context, r,
      onReject: () => _reject(r), onSendPrice: () => _sendPrice(r));

  Future<void> _reject(Requirement r) async {
    try {
      await _api.patch('/requirements/${r.id}/reject', {}, auth: true);
      await _load();
      if (!mounted) return;
      showSuccessMessage(context, 'Request rejected.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not reject: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: widget.asTab
              ? null
              : BackButton(onPressed: () => Navigator.of(context).pop()),
          titleSpacing: widget.asTab ? OneHubTheme.pageMargin : null,
          title: const Text('Incoming requests')),
      body: PageGlow(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: OneHubTheme.pageMargin, vertical: 8),
              children: [
                Text(
                  'Send a price to take a job. The customer picks from the prices they get.',
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
                else if (_requests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('No new requests right now.',
                        style:
                            OneHubTextStyles.bodyText(context.statusWarning)),
                  )
                else
                  for (final r in _requests)
                    _RequestCard(
                        request: r,
                        onReject: () => _reject(r),
                        onSendPrice: () => _sendPrice(r),
                        onOpen: () => _openDetail(r)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One incoming request as the shared [RequestCard]: status and when it was
/// posted, the title and description, then the customer, where they are and
/// how far, and any photos, with Reject and Send price on a new one.
class _RequestCard extends StatelessWidget {
  final Requirement request;
  final VoidCallback onReject;
  final VoidCallback onSendPrice;
  final VoidCallback onOpen;
  const _RequestCard(
      {required this.request,
      required this.onReject,
      required this.onSendPrice,
      required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final photos = request.photoUrls.length;
    final distance = request.distanceKm;
    final place = [
      if (request.customerPlace != null) request.customerPlace!,
      if (distance != null) '${distance.toStringAsFixed(1)} km',
    ].join(' · ');
    final stage = incomingStageOf(request);
    final bid = bidRangeLabel(request);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: RequestCard(
        statusLabel: incomingStageLabel(stage),
        statusColor: incomingStageColor(context, stage),
        postedAt: request.createdAt,
        title: request.heading,
        description: request.title.isNotEmpty ? request.description : '',
        facts: [
          if (request.customerName != null)
            RequestCardFact('CUSTOMER', request.customerName!),
          if (place.isNotEmpty) RequestCardFact('LOCATION', place),
          if (bid != null) RequestCardFact('YOUR BID', bid),
          if (photos > 0)
            RequestCardFact(
                'PHOTOS', photos == 1 ? '1 photo' : '$photos photos'),
        ],
        footer: stage == IncomingStage.newRequest
            ? _NewRequestActions(onReject: onReject, onSendPrice: onSendPrice)
            : null,
        onTap: onOpen,
      ),
    );
  }
}

/// Reject and Send price, on a new request's card and its detail page.
/// The full request: whole description, timeline, the provider's own price
/// once sent, the preferred date and photo count. A new request keeps Reject
/// and Send price at the bottom; they close the detail first, then call
/// [onReject] or [onSendPrice]. Opened from Incoming requests and from a
/// notification about the request.
Future<void> openIncomingDetail(
  BuildContext context,
  Requirement r, {
  required VoidCallback onReject,
  required VoidCallback onSendPrice,
}) {
  final stage = incomingStageOf(r);
  return openJobDetail(
    context,
    r,
    statusLabel: incomingStageLabel(stage),
    statusColor: incomingStageColor(context, stage),
    steps: jobTimeline(stage),
    action: stage == IncomingStage.newRequest
        ? Builder(
            builder: (ctx) => _NewRequestActions(
              onReject: () {
                Navigator.of(ctx).pop();
                onReject();
              },
              onSendPrice: () {
                Navigator.of(ctx).pop();
                onSendPrice();
              },
            ),
          )
        : null,
  );
}

/// Opens the request with [requirementId], as tapping one of its
/// notifications does: the same detail as Incoming requests, with Reject and
/// Send price on a new one. It loads this provider's requests to find it, and
/// says so instead when the request is gone (rejected by this provider) or
/// the list cannot load. Takes an optional [client] like the screens do.
Future<void> openIncomingById(BuildContext context, String requirementId,
    {ApiClient? client}) async {
  final ApiClient api_ = client ?? api;
  void say(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Requirement? found;
  var problem = 'This request is no longer available.';
  try {
    final json = await api_.get('/requirements/incoming') as List;
    for (final item in json) {
      final r = Requirement.fromJson(item as Map<String, dynamic>);
      if (r.id == requirementId && r.myResponse != RequestStatus.rejected) {
        found = r;
        break;
      }
    }
  } catch (_) {
    problem = 'Could not open this request. Pull down and try again.';
  }
  if (!context.mounted) return;
  final r = found;
  if (r == null) {
    say(problem);
    return;
  }
  await openIncomingDetail(
    context,
    r,
    onReject: () async {
      try {
        await api_.patch('/requirements/${r.id}/reject', {}, auth: true);
        if (context.mounted) showSuccessMessage(context, 'Request rejected.');
      } catch (e) {
        if (context.mounted) say('Could not reject: $e');
      }
    },
    onSendPrice: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PriceRangeScreen(requirementId: r.id, client: client))),
  );
}

class _NewRequestActions extends StatelessWidget {
  final VoidCallback onReject;
  final VoidCallback onSendPrice;
  const _NewRequestActions({required this.onReject, required this.onSendPrice});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.statusDanger,
              side: BorderSide(
                  color: context.statusDanger.withValues(alpha: 0.5)),
            ),
            child: const Text('Reject'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: PrimaryCta(
                onPressed: onSendPrice, child: const Text('Send price'))),
      ],
    );
  }
}
