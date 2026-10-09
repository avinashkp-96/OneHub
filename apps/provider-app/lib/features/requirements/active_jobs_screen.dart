import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';

enum _JobState { awaitingSelection, selected, notSelected, completed }

_JobState? _stateFor(Requirement r) {
  if (r.bids.isEmpty) return null; // this provider hasn't bid on it (yet)
  final myBid = r.bids.first;
  if (r.status == RequestStatus.completed && myBid.confirmed) {
    return _JobState.completed;
  }
  if (r.status == RequestStatus.confirmed ||
      r.status == RequestStatus.completed) {
    return myBid.confirmed ? _JobState.selected : _JobState.notSelected;
  }
  if (r.status == RequestStatus.bidReceived) return _JobState.awaitingSelection;
  return null;
}

// docx 5.6 — Job Confirmation & Completion: Awaiting Selection / Selected /
// Not Selected, and the "Mark as Completed" action once selected.
// Restyled to match the other redesigned list screens (no new reference —
// applied on request): PageGlow, back-only AppBar plus in-body heading, and
// each job as a bordered card with a status badge. Takes an optional
// [client], like SignupScreen, so tests can use a fake API.
class ActiveJobsScreen extends StatefulWidget {
  final ApiClient? client;
  const ActiveJobsScreen({super.key, this.client});

  @override
  State<ActiveJobsScreen> createState() => _ActiveJobsScreenState();
}

class _ActiveJobsScreenState extends State<ActiveJobsScreen> {
  List<Requirement> _jobs = [];
  bool _loading = true;
  String? _error;
  final Set<String> _completing = {};

  ApiClient get _api => widget.client ?? api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await _api.get('/requirements/incoming') as List;
      final all = json
          .map((r) => Requirement.fromJson(r as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _jobs = all.where((r) => _stateFor(r) != null).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load active jobs: $e';
        _loading = false;
      });
    }
  }

  Future<void> _markCompleted(Requirement r) async {
    setState(() {
      _completing.add(r.id);
      _error = null;
    });
    try {
      await _api.patch('/requirements/${r.id}/complete', {}, auth: true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not mark this job complete: $e');
    } finally {
      if (mounted) setState(() => _completing.remove(r.id));
    }
  }

  // The detail view is read-only: Mark as Completed stays on the card so
  // there is one place to do it.
  void _openDetail(Requirement job) {
    final state = _stateFor(job)!;
    final bid = job.bids.first;
    final lo = (bid.refinedMinPrice ?? bid.initialMinPrice).round();
    final hi = (bid.refinedMaxPrice ?? bid.initialMaxPrice).round();
    final awaiting = state == _JobState.awaitingSelection;
    final lost = state == _JobState.notSelected;
    final done = state == _JobState.completed;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => RequestDetailScreen(
        heading: 'Job',
        description: job.description,
        statusLabel: _jobLabel(state),
        statusColor: _jobColor(ctx, state),
        steps: [
          const TimelineStep('Bid submitted', TimelineState.done),
          TimelineStep('Customer chooses a provider',
              awaiting ? TimelineState.current : TimelineState.done),
          if (lost)
            const TimelineStep('Not selected', TimelineState.current)
          else ...[
            TimelineStep(
                'Job in progress',
                awaiting
                    ? TimelineState.todo
                    : done
                        ? TimelineState.done
                        : TimelineState.current),
            TimelineStep(
                'Completed', done ? TimelineState.done : TimelineState.todo),
          ],
        ],
        facts: [
          DetailFact('Your bid', '₹$lo - ₹$hi'),
          DetailFact('Photos', '${job.photoUrls.length}'),
        ],
      ),
    ));
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
                Text('Active jobs',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 26)),
                const SizedBox(height: 8),
                Text('Where each of your bids stands.',
                    style: OneHubTextStyles.bodyText(textSecondary)),
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
                else if (_jobs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('No active jobs right now.',
                        style:
                            OneHubTextStyles.bodyText(context.statusWarning)),
                  )
                else
                  for (final job in _jobs)
                    _JobCard(
                      job: job,
                      onOpen: () => _openDetail(job),
                      onMarkCompleted: () => _markCompleted(job),
                      busy: _completing.contains(job.id),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Requirement job;
  final VoidCallback onMarkCompleted;
  final bool busy;
  final VoidCallback onOpen;
  const _JobCard(
      {required this.job,
      required this.onOpen,
      required this.onMarkCompleted,
      required this.busy});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final state = _stateFor(job)!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                job.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: OneHubTextStyles.bodyText(textPrimary)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TintedBadge(
                    label: _label(state), color: _color(context, state)),
              ),
              if (state == _JobState.selected) ...[
                const SizedBox(height: 8),
                Text('You were picked. Go ahead with the job.',
                    style: OneHubTextStyles.bodyText(textSecondary)),
                const SizedBox(height: 16),
                PrimaryCta(
                  onPressed: busy ? null : onMarkCompleted,
                  child: Text(busy ? 'Marking complete…' : 'Mark as Completed'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _label(_JobState state) => _jobLabel(state);

  Color _color(BuildContext context, _JobState state) =>
      _jobColor(context, state);
}

String _jobLabel(_JobState state) => switch (state) {
      _JobState.awaitingSelection => 'AWAITING SELECTION',
      _JobState.selected => 'SELECTED',
      _JobState.notSelected => 'NOT SELECTED',
      _JobState.completed => 'COMPLETED',
    };

Color _jobColor(BuildContext context, _JobState state) => switch (state) {
      _JobState.awaitingSelection => context.statusWarning,
      _JobState.selected => context.statusSuccess,
      _JobState.notSelected => context.statusDanger,
      _JobState.completed => context.statusSuccess,
    };
