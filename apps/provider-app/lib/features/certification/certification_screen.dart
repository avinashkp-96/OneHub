import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';

// Provider certification, opened from the "Get certified" card on the
// dashboard. Matches the other provider screens (PageGlow, back-only AppBar
// plus in-body heading, one GlowCard, bordered tiles) — no new reference,
// applied on request.
//
// The five steps and how far along they are, are explicit dummy data: there
// is no certification endpoint to read them from yet. Replace
// [certificationSteps] when one exists. It lives here, not in the dashboard,
// so the dashboard's progress card and this checklist always agree.
enum CertificationState { done, current, todo }

class CertificationStep {
  final String title;
  final String description;
  final CertificationState state;
  const CertificationStep(this.title, this.description, this.state);
}

const certificationSteps = [
  CertificationStep('Verify your ID', 'Aadhaar or PAN, checked by an admin',
      CertificationState.done),
  CertificationStep('Complete your profile',
      'Photo, service area and bank or UPI details', CertificationState.done),
  CertificationStep('Finish 5 jobs',
      'Jobs that customers have marked completed', CertificationState.done),
  CertificationStep('Reach a 4.0 rating',
      'The average of your customer ratings', CertificationState.current),
  CertificationStep('Pass the skills check',
      'A short quiz for your service category', CertificationState.todo),
];

int get certificationStepsDone =>
    certificationSteps.where((s) => s.state == CertificationState.done).length;

class CertificationScreen extends StatelessWidget {
  const CertificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final lineColor =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final total = certificationSteps.length;
    final done = certificationStepsDone;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Get certified',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text('Certified providers get more requests.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Your progress',
                                style: OneHubTextStyles.bodyText(textPrimary)
                                    .copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                          ),
                          Text('$done of $total steps',
                              style: OneHubTextStyles.fieldLabel(textMuted)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          for (var i = 0; i < total; i++)
                            Expanded(
                              child: Container(
                                height: 6,
                                margin: EdgeInsets.only(
                                    right: i == total - 1 ? 0 : 5),
                                decoration: BoxDecoration(
                                  color: i < done
                                      ? OneHubColors.primary
                                      : lineColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text('Your checklist',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              for (var i = 0; i < total; i++)
                _StepTile(number: i + 1, step: certificationSteps[i]),
              const SizedBox(height: 12),
              // Disabled until every step is done. Applying has no backend yet,
              // so it stays disabled even once the (dummy) steps are all done.
              const PrimaryCta(
                  onPressed: null, child: Text('Apply for certification')),
              const SizedBox(height: 10),
              Text(
                'Finish all $total steps to apply.',
                textAlign: TextAlign.center,
                style: OneHubTextStyles.fieldLabel(textMuted)
                    .copyWith(letterSpacing: 0, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int number;
  final CertificationStep step;
  const _StepTile({required this.number, required this.step});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final border =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final done = step.state == CertificationState.done;
    final current = step.state == CertificationState.current;

    final badgeColor = done
        ? context.statusSuccess
        : current
            ? context.statusWarning
            : textMuted;
    final badgeLabel = done
        ? 'DONE'
        : current
            ? 'IN PROGRESS'
            : 'TO DO';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        side: BorderSide(color: current ? OneHubColors.primary : border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? context.statusSuccess.withValues(alpha: 0.14)
                    : Colors.transparent,
                border:
                    Border.all(color: done ? context.statusSuccess : border),
              ),
              child: done
                  ? Icon(OneHubIcons.successCheck,
                      size: 18, color: context.statusSuccess)
                  : Text('$number',
                      style: OneHubTextStyles.bodyText(textMuted)
                          .copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title,
                      style: OneHubTextStyles.bodyText(textPrimary)
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(step.description,
                      style: OneHubTextStyles.fieldLabel(textMuted)
                          .copyWith(letterSpacing: 0, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TintedBadge(label: badgeLabel, color: badgeColor),
          ],
        ),
      ),
    );
  }
}
