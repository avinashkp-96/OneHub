import 'package:flutter/material.dart';
import 'onehub_colors.dart';
import 'onehub_theme.dart';

class CurvedNavItem {
  final IconData icon;
  final String label;
  const CurvedNavItem({required this.icon, required this.label});
}

/// A floating bottom navigation bar, per a reference design
/// (dribbble.com/shots/26136769, "Navigation bar liquid-style"): a solid,
/// opaque, fully-rounded pill with icon-only tabs (no labels, not even on
/// the selected one — `label` is still carried per item for semantics) and
/// a glowing gradient "liquid" blob that slides to whichever tab is
/// selected. Replaced an earlier wavy-top, frosted-glass, label-on-select
/// design per explicit instruction to match this reference instead —
/// solid over blurred, icon-only over labeled.
///
/// The blob's look (radial purple-to-blue gradient, soft outer glow, a
/// glossy highlight) is static; only its position animates between tabs.
/// The reference's own shape-morphing liquid animation is a lot more
/// involved (a custom animated painter deforming the blob's outline in
/// transit) and was explicitly descoped in favor of this simpler version.
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
    final inactive =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(OneHubTheme.radiusPillBadge),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8))
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: slotWidth * selectedIndex,
                    top: 0,
                    bottom: 0,
                    width: slotWidth,
                    child: const Center(child: _LiquidBlob(size: 44)),
                  ),
                  Row(
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
                              child: Center(
                                child: Icon(
                                  items[i].icon,
                                  size: 22,
                                  color: i == selectedIndex
                                      ? Colors.white
                                      : inactive,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The glowing gradient circle behind the selected tab — purple-to-blue
/// radial gradient (`OneHubColors.accentPurple` -> `.primary`, the app's
/// existing palette, not new colors), a soft outer glow, and a small
/// glossy highlight offset toward the top-left like a light reflection.
class _LiquidBlob extends StatelessWidget {
  final double size;
  const _LiquidBlob({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 0.9,
          colors: [OneHubColors.accentPurple, OneHubColors.primary],
        ),
        boxShadow: [
          BoxShadow(
              color: OneHubColors.primary.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 1)
        ],
      ),
      child: Align(
        alignment: const Alignment(-0.4, -0.4),
        child: Container(
          width: size * 0.35,
          height: size * 0.35,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.white.withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0)
            ]),
          ),
        ),
      ),
    );
  }
}
