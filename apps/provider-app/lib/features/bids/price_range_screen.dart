import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';

// docx 5.4 — Price Range & Contact Unlock. Covers: submit the initial bid,
// optionally pay to unlock the customer's contact, then submit a refined
// range once contact is unlocked.
// Restyled to match the rest of the redesigned screens (no new reference —
// applied on request): PageGlow, back-only AppBar plus in-body heading, and
// one GlowCard holding the price fields and the step-appropriate actions.
// Takes an optional [client], like SignupScreen, so tests can use a fake API.
class PriceRangeScreen extends StatefulWidget {
  final String requirementId;
  final ApiClient? client;
  const PriceRangeScreen({super.key, required this.requirementId, this.client});

  @override
  State<PriceRangeScreen> createState() => _PriceRangeScreenState();
}

class _PriceRangeScreenState extends State<PriceRangeScreen> {
  final _min = TextEditingController();
  final _max = TextEditingController();
  String? _bidId;
  bool _contactUnlocked = false;
  bool _busy = false;
  String? _error;

  ApiClient get _api => widget.client ?? api;

  Future<void> _submitBid() async {
    final min = double.tryParse(_min.text);
    final max = double.tryParse(_max.text);
    if (min == null || max == null) {
      setState(() => _error = 'Enter a valid min and max price.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _api.post(
        '/requirements/${widget.requirementId}/bids',
        {'minPrice': min, 'maxPrice': max},
        auth: true,
      );
      if (!mounted) return;
      setState(() => _bidId = result['id'] as String);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not submit bid: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlockContact() async {
    if (_bidId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // TODO: route through a real payment gateway before charging; this
      // calls the backend's unlock endpoint, which currently records the
      // ₹50 charge as SUCCESS unconditionally (see BidsService.unlockContact).
      await _api.post('/bids/$_bidId/unlock-contact', {}, auth: true);
      if (!mounted) return;
      setState(() => _contactUnlocked = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not unlock contact: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateRefinedBid() async {
    if (_bidId == null) return;
    final min = double.tryParse(_min.text);
    final max = double.tryParse(_max.text);
    if (min == null || max == null) {
      setState(() => _error = 'Enter a valid min and max price.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.patch(
          '/bids/$_bidId/refine', {'minPrice': min, 'maxPrice': max},
          auth: true);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not update bid: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _subtitle {
    if (_bidId == null) {
      return 'Give the customer a range. You can refine it after you talk.';
    }
    if (!_contactUnlocked) {
      return 'Bid sent. Unlock the customer\'s contact to talk and refine your price.';
    }
    return 'Contact unlocked. Call or message the customer, then update your price.';
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
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Your price range',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text(_subtitle, style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(_error!,
                              style: TextStyle(color: context.statusDanger)),
                        ),
                      const FieldLabel('MIN PRICE (₹)',
                          required: true, icon: OneHubIcons.wallet),
                      const SizedBox(height: OneHubTheme.gapFieldInternals),
                      TextField(
                        controller: _min,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'e.g. 500'),
                      ),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      const FieldLabel('MAX PRICE (₹)',
                          required: true, icon: OneHubIcons.wallet),
                      const SizedBox(height: OneHubTheme.gapFieldInternals),
                      TextField(
                        controller: _max,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(hintText: 'e.g. 1200'),
                      ),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      if (_bidId == null)
                        PrimaryCta(
                            onPressed: _busy ? null : _submitBid,
                            child: const Text('Submit Bid'))
                      else ...[
                        if (_contactUnlocked)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TintedBadge(
                                label: 'CONTACT UNLOCKED',
                                color: context.statusSuccess,
                                pill: true),
                          )
                        else
                          OutlinedButton(
                            onPressed: _busy ? null : _unlockContact,
                            child: const Text('Pay ₹50 to Contact Customer'),
                          ),
                        const SizedBox(height: 12),
                        PrimaryCta(
                          onPressed: _busy || !_contactUnlocked
                              ? null
                              : _updateRefinedBid,
                          child: const Text('Update Bid'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
