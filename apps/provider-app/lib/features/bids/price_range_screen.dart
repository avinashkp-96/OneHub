import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';

// docx 5.4 — Price Range & Contact Unlock. Covers: submit the initial bid,
// optionally pay to unlock the customer's contact, then submit a refined
// range once contact is unlocked.
class PriceRangeScreen extends StatefulWidget {
  final String requirementId;
  const PriceRangeScreen({super.key, required this.requirementId});

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
      final result = await api.post(
        '/requirements/${widget.requirementId}/bids',
        {'minPrice': min, 'maxPrice': max},
        auth: true,
      );
      setState(() => _bidId = result['id'] as String);
    } catch (e) {
      setState(() => _error = 'Could not submit bid: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _unlockContact() async {
    if (_bidId == null) return;
    setState(() => _busy = true);
    try {
      // TODO: route through a real payment gateway before charging; this
      // calls the backend's unlock endpoint, which currently records the
      // ₹50 charge as SUCCESS unconditionally (see BidsService.unlockContact).
      await api.post('/bids/$_bidId/unlock-contact', {}, auth: true);
      setState(() => _contactUnlocked = true);
    } catch (e) {
      setState(() => _error = 'Could not unlock contact: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _updateRefinedBid() async {
    if (_bidId == null) return;
    final min = double.tryParse(_min.text);
    final max = double.tryParse(_max.text);
    if (min == null || max == null) return;
    setState(() => _busy = true);
    try {
      await api.patch('/bids/$_bidId/refine', {'minPrice': min, 'maxPrice': max}, auth: true);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Could not update bid: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Price Range')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: context.statusDanger)),
              ),
            TextField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min price (₹)')),
            const SizedBox(height: 8),
            TextField(controller: _max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max price (₹)')),
            const SizedBox(height: 16),
            if (_bidId == null)
              PrimaryCta(onPressed: _busy ? null : _submitBid, child: const Text('Submit Bid'))
            else ...[
              if (!_contactUnlocked)
                OutlinedButton(onPressed: _busy ? null : _unlockContact, child: const Text('Pay ₹50 to Contact Customer'))
              else
                Text(
                  'Contact unlocked — call or message the customer, then refine your price.',
                  style: TextStyle(color: context.statusSuccess),
                ),
              const SizedBox(height: 12),
              PrimaryCta(
                onPressed: _busy || !_contactUnlocked ? null : _updateRefinedBid,
                child: const Text('Update Bid'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
