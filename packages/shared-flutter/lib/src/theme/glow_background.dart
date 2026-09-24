import 'package:flutter/material.dart';
import 'onehub_colors.dart';

/// The reference's decorative dark-mode background: three soft radial-
/// gradient glow blobs over the flat surface color, reproduced from the
/// live page's extracted CSS (see OneHubColors doc comment). Only renders
/// the glow in dark mode — the reference has no light-mode equivalent, and
/// the same blobs over a light surface would just look like smudges.
/// Wrap a screen's body in this where the reference's glow should show
/// (currently: auth screens only, not every screen in the app).
class GlowBackground extends StatelessWidget {
  final Widget child;
  const GlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (!dark) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Align(
            alignment: const Alignment(-0.7, 0.8),
            child: FractionallySizedBox(
              widthFactor: 0.9,
              heightFactor: 0.6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [OneHubColors.glowBlue1, OneHubColors.glowBlue1.withValues(alpha: 0)]),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0.9, -0.9),
            child: FractionallySizedBox(
              widthFactor: 0.7,
              heightFactor: 0.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [OneHubColors.glowPurple, OneHubColors.glowPurple.withValues(alpha: 0)]),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: const Alignment(0, 1.1),
            child: FractionallySizedBox(
              widthFactor: 1.2,
              heightFactor: 0.7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [OneHubColors.glowBlue2, OneHubColors.glowBlue2.withValues(alpha: 0)]),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
