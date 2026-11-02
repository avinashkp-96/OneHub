import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import 'job_detail.dart';

enum _JobState { selected, completed }

// A job is active only once the customer has accepted this provider's price.
// Before that (price sent, waiting, or another provider chosen) the request
// stays in Incoming requests.
_JobState? _stateFor(Requirement r) {
  if (r.bids.isEmpty || !r.bids.first.confirmed) return null;
  return r.status == RequestStatus.completed
      ? _JobState.completed
      : _JobState.selected;
}

// docx 5.6 — Job Confirmation & Completion: jobs whose price the customer
// accepted (Selected) and finished ones (Completed), with "Mark as Completed"
// once selected. Waiting and not-selected requests stay in Incoming requests.
// Restyled to match the other redesigned list screens (no new reference —
// applied on request): PageGlow, page title in the AppBar, and
// each job as the shared RequestCard (status, posted time, title,
// description, then customer, location and the provider's own bid), like
// Incoming requests. Takes an optional
// [client], like SignupScreen, so tests can use a fake API.
class ActiveJobsScreen extends StatefulWidget {
  final ApiClient? client;

  /// True when shown as the Jobs tab under the bottom bar: no back arrow.
  final bool asTab;
  const ActiveJobsScreen({super.key, this.client, this.asTab = false});

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
      if (!mounted) return;
      showSuccessMessage(context, 'Job marked as completed.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not mark this job complete: $e');
    } finally {
      if (mounted) setState(() => _completing.remove(r.id));
    }
  }

  // The detail view is read-only: Mark as Completed stays on the card so
  // there is one place to do it. Same page Incoming requests opens.
  void _openDetail(Requirement job) {
    final state = _stateFor(job)!;
    openJobDetail(
      context,
      job,
      statusLabel: _jobLabel(state),
      statusColor: _jobColor(context, state),
      steps: jobTimeline(switch (state) {
        _JobState.selected => IncomingStage.selected,
        _JobState.completed => IncomingStage.completed,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: widget.asTab
              ? null
              : BackButton(onPressed: () => Navigator.of(context).pop()),
          titleSpacing: widget.asTab ? OneHubTheme.pageMargin : null,
          title: const Text('Active jobs')),
      body: PageGlow(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: OneHubTheme.pageMargin, vertical: 8),
              children: [
                Text('Jobs where the customer accepted your price.',
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
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final state = _stateFor(job)!;
    final distance = job.distanceKm;
    final place = [
      if (job.customerPlace != null) job.customerPlace!,
      if (distance != null) '${distance.toStringAsFixed(1)} km',
    ].join(' · ');
    final bid = bidRangeLabel(job);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: RequestCard(
        statusLabel: _label(state),
        statusColor: _color(context, state),
        postedAt: job.createdAt,
        title: job.heading,
        description: job.title.isNotEmpty ? job.description : '',
        descriptionMaxLines: 2,
        facts: [
          if (job.customerName != null)
            RequestCardFact('CUSTOMER', job.customerName!),
          if (place.isNotEmpty) RequestCardFact('LOCATION', place),
          if (bid != null) RequestCardFact('YOUR BID', bid),
        ],
        footer: state == _JobState.selected
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('You were picked. Go ahead with the job.',
                      style: OneHubTextStyles.bodyText(textSecondary)),
                  const SizedBox(height: 12),
                  PrimaryCta(
                    onPressed: busy ? null : onMarkCompleted,
                    child:
                        Text(busy ? 'Marking complete…' : 'Mark as Completed'),
                  ),
                ],
              )
            : null,
        onTap: onOpen,
      ),
    );
  }

  String _label(_JobState state) => _jobLabel(state);

  Color _color(BuildContext context, _JobState state) =>
      _jobColor(context, state);
}

String _jobLabel(_JobState state) => switch (state) {
      _JobState.selected => 'SELECTED',
      _JobState.completed => 'COMPLETED',
    };

Color _jobColor(BuildContext context, _JobState state) => switch (state) {
      _JobState.selected => context.statusSuccess,
      _JobState.completed => context.statusSuccess,
    };
