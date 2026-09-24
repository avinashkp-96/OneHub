import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'onehub_colors.dart';

class CurvedNavItem {
  final IconData icon;
  final String label;
  const CurvedNavItem({required this.icon, required this.label});
}

/// A floating bottom navigation bar with a gently wavy top edge, per a
/// reference screenshot: icon-only tabs (no visible labels) on a dark,
/// rounded bar that floats above the screen edge, distinct from Material's
/// square-edged, full-width `NavigationBar` used previously. `label` is
/// still carried per item for semantics/tooltips even though it isn't
/// painted, so each tab stays accessible.
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
    final fill =
        dark ? OneHubColors.navBarFillDark : OneHubColors.navBarFillLight;
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
          child: CustomPaint(
            painter: _WaveNavPainter(fill: fill, border: border),
            child: Padding(
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
          ),
        ),
      ),
    );
  }
}

/// Paints a rounded-bottom bar shape whose top edge undulates in a gentle
/// wave instead of running straight, matching the reference's curved-top
/// silhouette.
class _WaveNavPainter extends CustomPainter {
  final Color fill;
  final Color border;
  static const _amplitude = 6.0;
  static const _cycles = 1.5;
  static const _bottomRadius = 26.0;

  const _WaveNavPainter({required this.fill, required this.border});

  double _waveY(double x, double width) {
    const baseline = _amplitude + 6;
    return baseline - _amplitude * math.sin(2 * math.pi * _cycles * x / width);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(0, _waveY(0, size.width));
    const steps = 48;
    for (var i = 1; i <= steps; i++) {
      final x = size.width * i / steps;
      path.lineTo(x, _waveY(x, size.width));
    }
    path
      ..lineTo(size.width, size.height - _bottomRadius)
      ..quadraticBezierTo(
          size.width, size.height, size.width - _bottomRadius, size.height)
      ..lineTo(_bottomRadius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - _bottomRadius)
      ..close();

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.35), 10, false);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveNavPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.border != border;
}
