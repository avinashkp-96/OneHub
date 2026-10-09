import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';

// Provider availability and service area, reached from the Profile screen.
// Same shell as the other provider screens (PageGlow, back-only AppBar plus
// in-body heading, one GlowCard, bordered cards) — no new reference, applied
// on request.
//
// There is no availability endpoint yet, so "Save changes" only updates the
// in-memory [providerAvailability] below, which the Profile screen reads for
// its coverage row. It resets when the app restarts and tells the backend
// nothing. Replace the notifier with a fetch and save when the API exists.

const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const coverageOptionsKm = [2, 5, 10, 15, 25];

class Availability {
  final int radiusKm;
  final Set<int> days; // indexes into [weekdayLabels]
  final TimeOfDay start;
  final TimeOfDay end;
  const Availability({
    required this.radiusKm,
    required this.days,
    required this.start,
    required this.end,
  });

  Availability copyWith(
          {int? radiusKm, Set<int>? days, TimeOfDay? start, TimeOfDay? end}) =>
      Availability(
        radiusKm: radiusKm ?? this.radiusKm,
        days: days ?? this.days,
        start: start ?? this.start,
        end: end ?? this.end,
      );
}

final providerAvailability = ValueNotifier<Availability>(const Availability(
  radiusKm: 5,
  days: {0, 1, 2, 3, 4, 5},
  start: TimeOfDay(hour: 9, minute: 0),
  end: TimeOfDay(hour: 18, minute: 0),
));

int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late Availability _draft = providerAvailability.value;
  String? _error;

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
        context: context, initialTime: start ? _draft.start : _draft.end);
    if (picked == null || !mounted) return;
    setState(() {
      _draft =
          start ? _draft.copyWith(start: picked) : _draft.copyWith(end: picked);
      _error = null;
    });
  }

  void _toggleDay(int i) {
    final days = {..._draft.days};
    days.contains(i) ? days.remove(i) : days.add(i);
    setState(() {
      _draft = _draft.copyWith(days: days);
      _error = null;
    });
  }

  void _save() {
    if (_draft.days.isEmpty) {
      setState(() => _error = 'Pick at least one working day.');
      return;
    }
    if (_minutes(_draft.end) <= _minutes(_draft.start)) {
      setState(() => _error = 'Closing time must be after opening time.');
      return;
    }
    providerAvailability.value = _draft;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
        .showSnackBar(const SnackBar(content: Text('Availability saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    Widget section(String text) => Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 12),
          child: Text(text,
              style: OneHubTextStyles.pageHeading(textPrimary)
                  .copyWith(fontSize: 18)),
        );

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Availability',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text('When and how far you take jobs.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WORKING HOURS',
                          style: OneHubTextStyles.fieldLabel(textMuted)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: _TimeButton(
                                  label: 'OPENS',
                                  time: _draft.start,
                                  onTap: () => _pickTime(start: true))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _TimeButton(
                                  label: 'CLOSES',
                                  time: _draft.end,
                                  onTap: () => _pickTime(start: false))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              section('Working days'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < weekdayLabels.length; i++)
                    _Choice(
                      label: weekdayLabels[i],
                      selected: _draft.days.contains(i),
                      onTap: () => _toggleDay(i),
                    ),
                ],
              ),
              section('Service area'),
              Text('Jobs within this distance of you.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final km in coverageOptionsKm)
                    _Choice(
                      label: '$km km',
                      selected: _draft.radiusKm == km,
                      onTap: () => setState(
                          () => _draft = _draft.copyWith(radiusKm: km)),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: context.statusDanger)),
              ],
              const SizedBox(height: 32),
              PrimaryCta(onPressed: _save, child: const Text('Save changes')),
              const SizedBox(height: 12),
              Text('Saved on this device only for now.',
                  textAlign: TextAlign.center,
                  style: OneHubTextStyles.fieldLabel(textMuted)
                      .copyWith(letterSpacing: 0, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeButton(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final fill =
        dark ? OneHubColors.inputFillDark : OneHubColors.inputFillLight;
    final border =
        dark ? OneHubColors.inputBorderDark : OneHubColors.inputBorderLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OneHubTheme.radiusInputField),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(OneHubTheme.radiusInputField),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: OneHubTextStyles.fieldLabel(textMuted)),
            const SizedBox(height: 4),
            Text(time.format(context),
                style: OneHubTextStyles.bodyText(textPrimary)
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Choice(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final border =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OneHubTheme.radiusInputField),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? OneHubColors.primary.withValues(alpha: 0.16) : null,
          borderRadius: BorderRadius.circular(OneHubTheme.radiusInputField),
          border: Border.all(
              color: selected ? OneHubColors.primary : border,
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: OneHubTextStyles.bodyText(
                    selected ? OneHubColors.primary : textPrimary)
                .copyWith(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
