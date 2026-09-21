import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';

// docx 4.4 — Provider Responses & Bids. Shows the price range each accepted
// provider has submitted, and lets the customer confirm one to close bidding.
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
      final json = await api.get('/requirements/${widget.requirementId}/bids') as List;
      setState(() {
        _bids = json.map((b) => Bid.fromJson(b as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
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
      setState(() => _error = 'Could not confirm this provider: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bids received')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_bids.isEmpty) const Text('No bids yet. Providers who accept your request will appear here.'),
                  for (final bid in _bids)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(_priceRangeLabel(bid)),
                        subtitle: Text(bid.contactUnlocked ? 'Contacted you' : 'Not yet contacted you'),
                        trailing: bid.confirmed
                            ? const Chip(label: Text('Confirmed'))
                            : TextButton(onPressed: () => _confirm(bid), child: const Text('Confirm Provider')),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _priceRangeLabel(Bid bid) {
    final min = bid.refinedMinPrice ?? bid.initialMinPrice;
    final max = bid.refinedMaxPrice ?? bid.initialMaxPrice;
    return '₹${min.toStringAsFixed(0)}–₹${max.toStringAsFixed(0)}';
  }
}
