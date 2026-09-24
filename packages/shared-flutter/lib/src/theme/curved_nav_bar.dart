import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'onehub_colors.dart';

class CurvedNavItem {
  final IconData icon;
  final String label;
  const CurvedNavItem({required this.icon, required this.label});
}

/// A floating bottom navigation bar with a gently wavy top edge, per a
/// reference screenshot: icon-only tabs (no visible labels) on a frosted
/// glass bar that floats above the screen edge, distinct from Material's
/// square-edged, full-width `NavigationBar` used previously. `label` is
/// still carried per item for semantics/tooltips even though it isn't
/// painted, so each tab stays accessible.
///
/// The bar has no solid fill — a `BackdropFilter` blurs whatever scrolls
/// behind it, tinted by a translucent version of `OneHubColors.navBarFillDark`/
/// `.navBarFillLight` (not a semi-transparent app color; the blur itself is
/// what makes content behind it legible instead of just dimmed).
class CurvedNavBar extends StatelessWidget {
  final List<CurvedNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const CurvedNavBar(
      {super.key,
      required this.items,
      required this.selectedIndex,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint =
        (dark ? OneHubColors.navBarFillDark : OneHubColors.navBarFillLight)
            .withValues(alpha: 0.45);
    final border =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final inactive =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 64,
          child: Stack(
            children: [
              const Positioned.fill(
                  child: CustomPaint(painter: _WaveShadowPainter())),
              Positioned.fill(
                child: ClipPath(
                  clipper: const _WaveClipper(),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: DecoratedBox(decoration: BoxDecoration(color: tint)),
                  ),
                ),
              ),
              Positioned.fill(
                  child:
                      CustomPaint(painter: _WaveBorderPainter(border: border))),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == selectedIndex,
                          label: items[i].label,
                          child: InkWell(
                            onTap: () => onSelected(i),
                            customBorder: const CircleBorder(),
                            child: Icon(
                              items[i].icon,
                              size: 22,
                              color: i == selectedIndex
                                  ? OneHubColors.primary
                                  : inactive,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The rounded-bottom, wavy-top bar silhouette, shared by the clipper (for
/// the blur) and the shadow/border painters.
Path _wavePath(Size size) {
  const amplitude = 6.0;
  const cycles = 1.5;
  const bottomRadius = 26.0;
  const baseline = amplitude + 6;

  double waveY(double x) =>
      baseline - amplitude * math.sin(2 * math.pi * cycles * x / size.width);

  final path = Path()..moveTo(0, waveY(0));
  const steps = 48;
  for (var i = 1; i <= steps; i++) {
    final x = size.width * i / steps;
    path.lineTo(x, waveY(x));
  }
  path
    ..lineTo(size.width, size.height - bottomRadius)
    ..quadraticBezierTo(
        size.width, size.height, size.width - bottomRadius, size.height)
    ..lineTo(bottomRadius, size.height)
    ..quadraticBezierTo(0, size.height, 0, size.height - bottomRadius)
    ..close();
  return path;
}

class _WaveClipper extends CustomClipper<Path> {
  const _WaveClipper();

  @override
  Path getClip(Size size) => _wavePath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _WaveShadowPainter extends CustomPainter {
  const _WaveShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawShadow(
        _wavePath(size), Colors.black.withValues(alpha: 0.35), 10, false);
  }

  @override
  bool shouldRepaint(covariant _WaveShadowPainter oldDelegate) => false;
}

class _WaveBorderPainter extends CustomPainter {
  final Color border;
  const _WaveBorderPainter({required this.border});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _wavePath(size),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveBorderPainter oldDelegate) =>
      oldDelegate.border != border;
}
