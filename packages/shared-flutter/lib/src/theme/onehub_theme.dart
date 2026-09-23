import 'package:flutter/material.dart';
import 'onehub_colors.dart';

/// Shared Material 3 theme for the customer and provider apps. Both apps
/// should use this instead of building their own ThemeData, so a palette or
/// typography change only has to happen in one place.
///
/// Style reference: a "PetCare" app mockup the user supplied directly —
/// indigo-on-lavender, pill-shaped buttons, large-radius shadowed (not
/// outlined) cards, and a light/transparent app bar with dark text rather
/// than a bold color bar, which would clash with everything else in that
/// reference being pastel. Palette and shape language only, not an exact
/// layout clone of that mockup's specific screens.
///
/// Noto Sans over Roboto/Inter: this app's provider base spans Indian cities
/// and regional-language UI is a near-term ask, not a hypothetical, so the
/// font needs Devanagari/regional-script coverage from day one rather than a
/// swap later.
///
/// Referenced by family name rather than through the `google_fonts` package:
/// that package's runtime API fetches the font over the network the first
/// time it's used and has no offline fallback, which both broke every widget
/// test touching this theme and would be a real production risk (a customer
/// on a bad connection shouldn't be blocked from seeing basic UI text). On
/// web, `apps/*/web/index.html` loads Noto Sans via a Google Fonts
/// stylesheet `<link>`. On mobile, until the actual .ttf files are bundled
/// as assets (tracked as a known gap in CLAUDE.md), this falls back to the
/// platform's default font rather than failing.
abstract final class OneHubTheme {
  static const fontFamily = 'Noto Sans';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: dark ? OneHubColors.primaryDark : OneHubColors.primary,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: dark ? OneHubColors.surfaceDark : OneHubColors.surfaceLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Large radius + a soft shadow instead of an outline — cards read as
      // "floating" on the lavender background, matching the reference,
      // rather than as bordered Material containers.
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        color: dark ? OneHubColors.inputFillDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      // Pill-shaped, per the reference, not just rounded-rectangle. A fixed
      // 48px minimum height (not full width, by design — see PrimaryCta
      // below for page-level CTAs) so every button is an easy outdoor/
      // gloved-hand tap target, whether it's a page-level CTA or one of a
      // pair in a Row.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: const StadiumBorder()),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? OneHubColors.inputFillDark : OneHubColors.inputFillLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
      ),
    );
  }
}

/// A page-level primary CTA ("Login", "Send Request", "Submit Bid") that
/// spans the full width available. Buttons used inline (e.g. Accept/Reject
/// side by side in a Row) should stay plain `FilledButton`/`OutlinedButton` —
/// forcing full width there fights the Row's layout instead of the other
/// widget in it.
class PrimaryCta extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const PrimaryCta({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: onPressed, child: child),
    );
  }
}

/// Semantic status colors for request/bid/job states (docx sections 4.4-4.6,
/// 5.4-5.6): confirmed/completed reads success, pending/awaiting reads
/// warning, rejected/expired reads danger. Kept separate from ColorScheme
/// because Material 3 has no built-in success/warning slot.
extension OneHubStatusColors on BuildContext {
  Color get statusSuccess => OneHubColors.success;
  Color get statusWarning => OneHubColors.warning;
  Color get statusDanger => OneHubColors.danger;
}
