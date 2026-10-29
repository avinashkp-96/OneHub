import 'package:flutter/material.dart';
import 'onehub_colors.dart';
import 'onehub_theme.dart';

/// A form card with a soft blue ambient glow (`OneHubColors.glowBlue1`,
/// #2563EB) that lives inside the card, clipped to its own rounded corners,
/// anchored bottom-left, behind the card's content. Scoped to the card —
/// never the page background — per explicit correction: the glow belongs
/// to the card component, and must never bleed past the card's boundary.
///
/// The companion top-right light glow and bottom-right blue glow live on
/// the page background instead (see [PageGlow]) — a deliberate exception
/// to "glows stay inside their component," per an explicit later
/// correction: those glows specifically belong behind the card, not
/// inside it.
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

/// Two subtle ambient glows on the page background, sitting behind the
/// page's content — typically a [GlowCard]: a light glow anchored
/// top-right, and a soft blue glow (`OneHubColors.glowBlue1`) anchored
/// bottom-right. Wrap a screen's body in this wherever these page-level
/// glows should show, applied consistently across every screen. Only
/// renders in dark mode, matching the reference.
///
/// When the enclosing [Scaffold] has an app bar, the body starts below it,
/// so the glows extend upward by the app bar's height and paint behind it
/// (the app bar is transparent). That anchors the top-right glow to the
/// page's real top edge instead of the line under the header.
class PageGlow extends StatelessWidget {
  final Widget child;
  const PageGlow({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!dark) return child;

    final scaffold = Scaffold.maybeOf(context);
    final appBarHeight = scaffold != null && scaffold.hasAppBar
        ? scaffold.appBarMaxHeight ?? 0.0
        : 0.0;

    Widget glow(Alignment alignment, Color color) => Positioned(
          top: -appBarHeight,
          left: 0,
          right: 0,
          bottom: 0,
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

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        glow(Alignment.topRight, OneHubColors.glowLight),
        glow(Alignment.bottomRight, OneHubColors.glowBlue1),
        child,
      ],
    );
  }
}
