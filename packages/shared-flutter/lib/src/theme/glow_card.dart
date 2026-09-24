import 'package:flutter/material.dart';
import 'onehub_colors.dart';
import 'onehub_theme.dart';

/// A form card with an ambient glow that lives inside the card, clipped to
/// its own rounded corners and anchored bottom-left, behind the card's
/// content. Replaces an earlier page-level `GlowBackground` (three glow
/// blobs behind the whole screen) per explicit correction: the glow belongs
/// to the card component, not the page background, and must never bleed
/// past the card's boundary. Apply the same principle to any future
/// component that wants a similar ambient-glow effect — scope and clip the
/// glow to that component, don't add another page-level glow.
///
/// Drop-in replacement for a bare `Card(child: ...)` on the auth screens.
/// Only renders the glow in dark mode, matching the reference (no light-
/// mode equivalent).
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

    return Container(
      decoration: BoxDecoration(
          color: cardFill,
          border: Border.all(color: cardBorder),
          borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (dark)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.75,
                    heightFactor: 0.55,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.bottomLeft,
                          radius: 1.1,
                          colors: [
                            OneHubColors.glowBlue1,
                            OneHubColors.glowBlue1.withValues(alpha: 0)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
