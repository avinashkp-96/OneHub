import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../bids/price_range_screen.dart';

// docx 5.3 — Incoming Requests. On Accept, moves to the Price Range screen (5.4).
// Restyled to match the customer app's list screens (no new reference —
// applied on request): PageGlow, back-only AppBar plus in-body heading, and
// each request as a bordered card with full-height Reject / Accept buttons.
// Takes an optional [client], like SignupScreen, so tests can use a fake API.
class IncomingRequestsScreen extends StatefulWidget {
  final ApiClient? client;
  const IncomingRequestsScreen({super.key, this.client});

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
        _requests = json
            .map((r) => Requirement.fromJson(r as Map<String, dynamic>))
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

  Future<void> _accept(Requirement r) async {
    try {
      await _api.patch('/requirements/${r.id}/accept', {}, auth: true);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) =>
                PriceRangeScreen(requirementId: r.id, client: widget.client)),
      );
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not accept: $e');
    }
  }

  Future<void> _reject(Requirement r) async {
    try {
      await _api.patch('/requirements/${r.id}/reject', {}, auth: true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not reject: $e');
    }
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
                Text('Incoming requests',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 26)),
                const SizedBox(height: 8),
                Text(
                  'Accept a job to send the customer your price range.',
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
                        onAccept: () => _accept(r),
                        onReject: () => _reject(r)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Requirement request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _RequestCard(
      {required this.request, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final photos = request.photoUrls.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              request.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: OneHubTextStyles.bodyText(textPrimary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            if (photos > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TintedBadge(
                    label: photos == 1 ? '1 PHOTO' : '$photos PHOTOS',
                    color: OneHubColors.primary),
              ),
            ],
            const SizedBox(height: 16),
            Row(
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
                        onPressed: onAccept, child: const Text('Accept'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
