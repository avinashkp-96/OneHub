import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import 'bid_list_screen.dart';
import 'rating_screen.dart';

// docx 4.4 "My Requests — Status View" + 4.5 "Booking / Request History"
// combined into one list, since both read from the same /requirements/mine
// endpoint and differ only in which statuses they'd normally filter to.
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
      setState(() {
        _requirements = json.map((r) => Requirement.fromJson(r as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
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
      if (confirmedBid == null) return; // shouldn't happen, but nothing sane to open
      final providerId = confirmedBid.providerId; // captured as final so the closure below can use it
      final alreadyRated = await api.get('/ratings/requirement/${r.id}');
      if (!mounted) return;
      if (alreadyRated != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You've already rated this job.")));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RatingScreen(requirementId: r.id, providerId: providerId)),
      );
      _load();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BidListScreen(requirementId: r.id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) Text(_error!, style: TextStyle(color: context.statusDanger)),
                  if (_requirements.isEmpty) const Text("You haven't posted any requirements yet."),
                  for (final r in _requirements)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(r.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_statusLabel(r.status)),
                        trailing: _statusColor(context, r.status) == null
                            ? const Icon(Icons.chevron_right)
                            : Icon(Icons.circle, size: 12, color: _statusColor(context, r.status)),
                        onTap: () => _open(r),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _statusLabel(RequestStatus status) => switch (status) {
        RequestStatus.sent => 'Sent',
        RequestStatus.accepted => 'Accepted',
        RequestStatus.rejected => 'Rejected',
        RequestStatus.bidReceived => 'Bids Received',
        RequestStatus.confirmed => 'Confirmed',
        RequestStatus.completed => 'Completed',
        RequestStatus.cancelled => 'Cancelled',
        RequestStatus.expired => 'Expired',
      };

  Color? _statusColor(BuildContext context, RequestStatus status) => switch (status) {
        RequestStatus.confirmed || RequestStatus.completed => context.statusSuccess,
        RequestStatus.bidReceived => context.statusWarning,
        RequestStatus.rejected || RequestStatus.cancelled || RequestStatus.expired => context.statusDanger,
        _ => null,
      };
}
