import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';

enum _JobState { awaitingSelection, selected, notSelected, completed }

_JobState? _stateFor(Requirement r) {
  if (r.bids.isEmpty) return null; // this provider hasn't bid on it (yet)
  final myBid = r.bids.first;
  if (r.status == RequestStatus.completed && myBid.confirmed) return _JobState.completed;
  if (r.status == RequestStatus.confirmed || r.status == RequestStatus.completed) {
    return myBid.confirmed ? _JobState.selected : _JobState.notSelected;
  }
  if (r.status == RequestStatus.bidReceived) return _JobState.awaitingSelection;
  return null;
}

// docx 5.6 — Job Confirmation & Completion: Awaiting Selection / Selected /
// Not Selected, and the "Mark as Completed" action once selected.
class ActiveJobsScreen extends StatefulWidget {
  const ActiveJobsScreen({super.key});

  @override
  State<ActiveJobsScreen> createState() => _ActiveJobsScreenState();
}

class _ActiveJobsScreenState extends State<ActiveJobsScreen> {
  List<Requirement> _jobs = [];
  bool _loading = true;
  String? _error;
  final Set<String> _completing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await api.get('/requirements/incoming') as List;
      final all = json.map((r) => Requirement.fromJson(r as Map<String, dynamic>)).toList();
      setState(() {
        _jobs = all.where((r) => _stateFor(r) != null).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load active jobs: $e';
        _loading = false;
      });
    }
  }

  Future<void> _markCompleted(Requirement r) async {
    setState(() => _completing.add(r.id));
    try {
      await api.patch('/requirements/${r.id}/complete', {}, auth: true);
      await _load();
    } catch (e) {
      setState(() => _error = 'Could not mark this job complete: $e');
    } finally {
      setState(() => _completing.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Active Jobs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) Text(_error!, style: TextStyle(color: context.statusDanger)),
                  if (_jobs.isEmpty) const Text('No active jobs right now.'),
                  for (final job in _jobs) _JobCard(job: job, onMarkCompleted: () => _markCompleted(job), busy: _completing.contains(job.id)),
                ],
              ),
            ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Requirement job;
  final VoidCallback onMarkCompleted;
  final bool busy;
  const _JobCard({required this.job, required this.onMarkCompleted, required this.busy});

  @override
  Widget build(BuildContext context) {
    final state = _stateFor(job)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.description),
            const SizedBox(height: 8),
            Text(_label(state), style: TextStyle(color: _color(context, state), fontWeight: FontWeight.bold)),
            if (state == _JobState.selected) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: busy ? null : onMarkCompleted,
                child: Text(busy ? 'Marking complete…' : 'Mark as Completed'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _label(_JobState state) => switch (state) {
        _JobState.awaitingSelection => 'Awaiting Selection',
        _JobState.selected => 'Selected — proceed with the job',
        _JobState.notSelected => 'Not Selected',
        _JobState.completed => 'Completed',
      };

  Color _color(BuildContext context, _JobState state) => switch (state) {
        _JobState.awaitingSelection => context.statusWarning,
        _JobState.selected => context.statusSuccess,
        _JobState.notSelected => context.statusDanger,
        _JobState.completed => context.statusSuccess,
      };
}
