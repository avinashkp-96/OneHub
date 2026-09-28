import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';

// docx 4.4 — Provider Responses & Bids. Shows the price range each accepted
// provider has submitted, and lets the customer confirm one to close bidding.
// Restyled to match the current OneHub design system (no new reference —
// applied on request, using existing tokens/components and general UX
// principles), matching the pattern set on post_requirement_screen.dart and
// rating_screen.dart: PageGlow behind the page, a back-only AppBar plus an
// in-body heading. Bid tiles are plain bordered cards rather than GlowCard,
// since GlowCard is reserved for the single primary form card per screen and
// this screen is a repeated list, not a form.
class BidListScreen extends StatefulWidget {
  final String requirementId;
  const BidListScreen({super.key, required this.requirementId});

  @override
  State<BidListScreen> createState() => _BidListScreenState();
}

class _BidListScreenState extends State<BidListScreen> {
  List<Bid> _bids = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json =
          await api.get('/requirements/${widget.requirementId}/bids') as List;
      if (!mounted) return;
      setState(() {
        _bids =
            json.map((b) => Bid.fromJson(b as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load bids: $e';
        _loading = false;
      });
    }
  }

  Future<void> _confirm(Bid bid) async {
    try {
      await api.patch('/bids/${bid.id}/confirm', {}, auth: true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not confirm this provider: $e');
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
                Text('Bids received',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 26)),
                const SizedBox(height: 8),
                Text(
                  'Compare providers and confirm the one you want.',
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
                else if (_bids.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No bids yet. Providers who accept your request will appear here.',
                      style: OneHubTextStyles.bodyText(context.statusWarning),
                    ),
                  )
                else
                  for (final bid in _bids)
                    _BidTile(bid: bid, onConfirm: () => _confirm(bid)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BidTile extends StatelessWidget {
  final Bid bid;
  final VoidCallback onConfirm;
  const _BidTile({required this.bid, required this.onConfirm});

  String get _priceRangeLabel {
    final min = bid.refinedMinPrice ?? bid.initialMinPrice;
    final max = bid.refinedMaxPrice ?? bid.initialMaxPrice;
    return '₹${min.toStringAsFixed(0)}–₹${max.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final cardBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        side: BorderSide(
            color: bid.confirmed ? OneHubColors.success : cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(OneHubIcons.wallet, color: textPrimary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_priceRangeLabel,
                      style: OneHubTextStyles.bodyText(textPrimary)
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  TintedBadge(
                    label: bid.contactUnlocked
                        ? 'CONTACTED YOU'
                        : 'NOT YET CONTACTED',
                    color: bid.contactUnlocked
                        ? OneHubColors.success
                        : context.statusWarning,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (bid.confirmed)
              const TintedBadge(
                  label: 'CONFIRMED', color: OneHubColors.success, pill: true)
            else
              OutlinedButton(
                onPressed: onConfirm,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Confirm'),
              ),
          ],
        ),
      ),
    );
  }
}
