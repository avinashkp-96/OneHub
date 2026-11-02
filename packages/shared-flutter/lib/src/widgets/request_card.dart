import 'package:flutter/material.dart';
import '../screens/notifications_screen.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_theme.dart';

/// A label and value in the bottom row of a [RequestCard], e.g. LOCATION /
/// Kochi · 6.7 km.
class RequestCardFact {
  final String label;
  final String value;
  const RequestCardFact(this.label, this.value);
}

/// "Posted 2 days ago", "Posted just now", "Posted 12 Oct".
String postedLabel(DateTime postedAt, DateTime now) {
  final label = relativeTimeLabel(postedAt, now);
  // Older posts come back as a date ("12 Oct"); the rest are relative.
  final isDate = RegExp(r'^\d+ [A-Z][a-z]{2}$').hasMatch(label);
  return 'Posted ${isDate ? 'on $label' : label.toLowerCase()}';
}

/// A service request card, used by both apps' request lists and the request
/// detail screen. A dark surface with the brand blue fading in from the
/// top-left corner (after a reference the user gave): a status pill and when it was
/// posted, the title in bold, the description, then up to a few
/// [facts] two to a row under a divider. An optional [footer] (e.g. Accept /
/// Reject) sits at the bottom, and [onTap] makes the whole card tappable.
class RequestCard extends StatelessWidget {
  final String statusLabel;
  final Color statusColor;
  final DateTime? postedAt;

  /// Fixes "now" for the posted label in tests.
  final DateTime? now;
  final String title;
  final String description;

  /// Null shows the whole description.
  final int? descriptionMaxLines;
  final List<RequestCardFact> facts;
  final Widget? footer;
  final VoidCallback? onTap;

  const RequestCard({
    super.key,
    required this.statusLabel,
    required this.statusColor,
    required this.title,
    this.description = '',
    this.postedAt,
    this.now,
    this.descriptionMaxLines = 3,
    this.facts = const [],
    this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final soft =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final faint =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final divider =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    // The card surface, with the brand blue fading in from the top-left
    // corner and gone by about two thirds of the way across.
    final base = dark ? OneHubColors.navBarFillDark : OneHubColors.cardFillLight;
    final tint = Color.alphaBlend(
        OneHubColors.primary.withValues(alpha: dark ? 0.22 : 0.12), base);
    final radius = BorderRadius.circular(OneHubTheme.radiusFormCard);
    final posted = postedAt;

    Widget fact(RequestCardFact f) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.label, style: OneHubTextStyles.fieldLabel(faint)),
            const SizedBox(height: 4),
            Text(f.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: OneHubTextStyles.pageHeading(textPrimary)
                    .copyWith(fontSize: 16, height: 1.2)),
          ],
        );

    final content = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TintedBadge(label: statusLabel, color: statusColor, pill: true),
              if (posted != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(postedLabel(posted, now ?? DateTime.now()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OneHubTextStyles.bodyText(faint)
                          .copyWith(fontSize: 12)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(title,
              style: OneHubTextStyles.pageHeading(textPrimary)
                  .copyWith(fontSize: 24, height: 1.15)),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(description,
                maxLines: descriptionMaxLines,
                overflow: descriptionMaxLines == null
                    ? null
                    : TextOverflow.ellipsis,
                style: OneHubTextStyles.bodyText(soft).copyWith(height: 1.45)),
          ],
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: divider),
            const SizedBox(height: 14),
            for (var i = 0; i < facts.length; i += 2) ...[
              if (i > 0) const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: fact(facts[i])),
                  const SizedBox(width: 16),
                  Expanded(
                      child: i + 1 < facts.length
                          ? fact(facts[i + 1])
                          : const SizedBox.shrink()),
                ],
              ),
            ],
          ],
          if (footer != null) ...[
            const SizedBox(height: 18),
            footer!,
          ],
        ],
      ),
    );

    return Container(
      key: const Key('request-card'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tint, base],
          stops: const [0, 0.7],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        border: Border.all(
            color: OneHubColors.primary.withValues(alpha: dark ? 0.28 : 0.2)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: content,
        ),
      ),
    );
  }
}
