import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../bids/price_range_screen.dart';

// docx 5.3 — Incoming Requests. On Accept, moves to the Price Range screen (5.4).
class IncomingRequestsScreen extends StatefulWidget {
  const IncomingRequestsScreen({super.key});

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen> {
  List<Requirement> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await api.get('/requirements/incoming') as List;
      setState(() {
        _requests = json.map((r) => Requirement.fromJson(r as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load incoming requests: $e';
        _loading = false;
      });
    }
  }

  Future<void> _accept(Requirement r) async {
    try {
      await api.patch('/requirements/${r.id}/accept', {}, auth: true);
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PriceRangeScreen(requirementId: r.id)));
      }
    } catch (e) {
      setState(() => _error = 'Could not accept: $e');
    }
  }

  Future<void> _reject(Requirement r) async {
    try {
      await api.patch('/requirements/${r.id}/reject', {}, auth: true);
      await _load();
    } catch (e) {
      setState(() => _error = 'Could not reject: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Requests')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  if (_requests.isEmpty) const Text('No new requests right now.'),
                  for (final r in _requests)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.description),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(onPressed: () => _reject(r), child: const Text('Reject')),
                                const SizedBox(width: 8),
                                FilledButton(onPressed: () => _accept(r), child: const Text('Accept')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
