import 'package:flutter/material.dart';
import '../theme/glow_card.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_icons.dart';
import '../theme/onehub_theme.dart';

enum TimelineState { done, current, todo }

/// One step of the progress timeline on [RequestDetailScreen].
class TimelineStep {
  final String label;
  final TimelineState state;
  const TimelineStep(this.label, this.state);
}

/// A label/value row in the "Details" card.
class DetailFact {
  final String label;
  final String value;
  const DetailFact(this.label, this.value);
}

/// Detail view for a request or job, identical for the customer and provider
/// apps, so it lives here and each app passes what it wants shown: the
/// request text, a status badge, a progress timeline, extra facts and an
/// optional [action] (a full-width button the app supplies). Same shell as
/// the other screens (PageGlow, back-only AppBar, in-body heading). The one
/// GlowCard holds the description and status; the timeline and facts are
/// plain bordered cards.
class RequestDetailScreen extends StatelessWidget {
  final String heading;
  final String description;
  final String statusLabel;
  final Color statusColor;
  final List<TimelineStep> steps;
  final List<DetailFact> facts;
  final Widget? action;
  const RequestDetailScreen({
    super.key,
    required this.heading,
    required this.description,
    required this.statusLabel,
    required this.statusColor,
    required this.steps,
    this.facts = const [],
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final divider =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text(heading,
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 26)),
              const SizedBox(height: OneHubTheme.sectionGap),
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TintedBadge(label: statusLabel, color: statusColor),
                      const SizedBox(height: 12),
                      Text(description,
                          style: OneHubTextStyles.bodyText(textPrimary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text('Progress',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        _TimelineRow(
                          step: steps[i],
                          last: i == steps.length - 1,
                          lineColor: divider,
                        ),
                    ],
                  ),
                ),
              ),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text('Details',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 18)),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < facts.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: divider),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(facts[i].label.toUpperCase(),
                                        style: OneHubTextStyles.fieldLabel(
                                            textMuted))),
                                Text(facts[i].value,
                                    style:
                                        OneHubTextStyles.bodyText(textSecondary)
                                            .copyWith(
                                                fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 26),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TimelineStep step;
  final bool last;
  final Color lineColor;
  const _TimelineRow(
      {required this.step, required this.last, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final done = step.state == TimelineState.done;
    final current = step.state == TimelineState.current;
    final accent = done
        ? context.statusSuccess
        : current
            ? OneHubColors.primary
            : textMuted;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? accent : Colors.transparent,
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: done
                      ? const Icon(OneHubIcons.successCheck,
                          size: 12, color: Colors.white)
                      : null,
                ),
                if (!last)
                  Expanded(
                    child: Container(
                        key: const Key('timeline-line'),
                        width: 2,
                        color: done ? accent : lineColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 18),
              child: Text(step.label,
                  style: OneHubTextStyles.bodyText(
                          step.state == TimelineState.todo
                              ? textMuted
                              : textPrimary)
                      .copyWith(
                          fontWeight:
                              current ? FontWeight.w700 : FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}
