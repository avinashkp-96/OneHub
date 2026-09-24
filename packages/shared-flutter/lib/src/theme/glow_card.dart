import 'package:flutter/material.dart';
import 'onehub_colors.dart';
import 'onehub_theme.dart';

/// A form card with two ambient glows that live inside the card, clipped to
/// its own rounded corners, behind the card's content: a soft blue glow
/// anchored bottom-left (`OneHubColors.glowBlue1`, #2563EB) and a subtle
/// light glow anchored top-right (`OneHubColors.glowLight`). Both stay
/// scoped to the card — never the page background — per explicit
/// correction: the glow belongs to the card component, and must never
/// bleed past the card's boundary. Apply the same principle to any future
/// component that wants a similar ambient-glow effect — scope and clip the
/// glow to that component, don't add a page-level glow.
///
/// This is the standing pattern for "form card"-style content (the single
/// primary card on a screen, e.g. login/signup) — not for repeated list-item
/// cards (dashboard sections, category tiles, request/bid list rows), which
/// would turn a subtle effect into a distracting, repeated one.
///
/// Drop-in replacement for a bare `Card(child: ...)`. Only renders the glow
/// in dark mode, matching the reference (no light-mode equivalent).
class GlowCard extends StatelessWidget {
  final Widget child;
  const GlowCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardFill =
        dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final cardBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final radius = BorderRadius.circular(OneHubTheme.radiusFormCard);

    Widget glow(Alignment alignment, Color color) => Positioned.fill(
          child: Align(
            alignment: alignment,
            child: FractionallySizedBox(
              widthFactor: 0.75,
              heightFactor: 0.55,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: alignment,
                    radius: 1.1,
                    colors: [color, color.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
          color: cardFill,
          border: Border.all(color: cardBorder),
          borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (dark) glow(Alignment.bottomLeft, OneHubColors.glowBlue1),
            if (dark) glow(Alignment.topRight, OneHubColors.glowLight),
            child,
          ],
        ),
      ),
    );
  }
}
