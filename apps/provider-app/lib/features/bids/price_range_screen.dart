import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';

// docx 5.4 — Price Range & Contact Unlock. Covers: submit the initial bid,
// optionally pay to unlock the customer's contact, then submit a refined
// range once contact is unlocked.
// Restyled to match the rest of the redesigned screens (no new reference —
// applied on request): PageGlow, page title in the AppBar, and
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
  // A problem that belongs to no field (no connection, an expired request),
  // shown above the form.
  String? _error;
  // Problems under the min and max price fields.
  final Map<String, String> _fieldErrors = {};

  ApiClient get _api => widget.client ?? api;

  void _clear(String field) {
    if (_fieldErrors.remove(field) != null) setState(() {});
  }

  /// The two prices, or null after flagging what is wrong under each field.
  (double, double)? _checkPrices() {
    final min = double.tryParse(_min.text.trim());
    final max = double.tryParse(_max.text.trim());
    final problems = {
      if (min == null || min < 0) 'min': 'Enter the lowest price you would charge.',
      if (max == null || max < 0) 'max': 'Enter the highest price you would charge.',
      if (min != null && max != null && max < min)
        'max': 'The highest price cannot be below the lowest.',
    };
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(problems);
      _error = null;
    });
    return problems.isEmpty ? (min!, max!) : null;
  }

  void _fail(String action, Object e) {
    final field = errorField(e, const {
      'min': ['minprice'],
      'max': ['maxprice'],
    });
    setState(() {
      if (field != null) {
        _fieldErrors[field] = userMessage(e);
      } else {
        _error = '$action ${userMessage(e)}';
      }
    });
  }

  Future<void> _submitBid() async {
    final prices = _checkPrices();
    if (prices == null) return;
    final (min, max) = prices;
    setState(() => _busy = true);
    try {
      final result = await _api.post(
        '/requirements/${widget.requirementId}/bids',
        {'minPrice': min, 'maxPrice': max},
        auth: true,
      );
      if (!mounted) return;
      setState(() => _bidId = result['id'] as String);
      showSuccessMessage(context, 'Bid sent to the customer.');
    } catch (e) {
      if (!mounted) return;
      _fail('Could not send your price.', e);
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
      showSuccessMessage(
          context, 'Contact unlocked. You can now call the customer.');
    } catch (e) {
      if (!mounted) return;
      _fail('Could not unlock the contact.', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateRefinedBid() async {
    if (_bidId == null) return;
    final prices = _checkPrices();
    if (prices == null) return;
    final (min, max) = prices;
    setState(() => _busy = true);
    try {
      await _api.patch(
          '/bids/$_bidId/refine', {'minPrice': min, 'maxPrice': max},
          auth: true);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final bar = successSnackBar(context, 'Bid updated.');
        Navigator.of(context).pop(true);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(bar);
      }
    } catch (e) {
      if (!mounted) return;
      _fail('Could not update your price.', e);
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
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Your price range')),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
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
                        onChanged: (_) => _clear('min'),
                        decoration: InputDecoration(
                            hintText: 'e.g. 500',
                            errorText: _fieldErrors['min']),
                      ),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      const FieldLabel('MAX PRICE (₹)',
                          required: true, icon: OneHubIcons.wallet),
                      const SizedBox(height: OneHubTheme.gapFieldInternals),
                      TextField(
                        controller: _max,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _clear('max'),
                        decoration: InputDecoration(
                            hintText: 'e.g. 1200',
                            errorText: _fieldErrors['max']),
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
