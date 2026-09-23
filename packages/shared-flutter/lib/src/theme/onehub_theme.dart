import 'package:flutter/material.dart';
import 'onehub_colors.dart';

/// Shared Material 3 theme for the customer and provider apps. Both apps
/// should use this instead of building their own ThemeData, so a palette or
/// typography change only has to happen in one place.
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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: OneHubColors.primary,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: brightness == Brightness.dark ? OneHubColors.surfaceDark : OneHubColors.surfaceLight,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      // A fixed 48px minimum height (not full width, by design — see
      // PrimaryCta below for page-level CTAs) so every button is an easy
      // outdoor tap target, whether it's a page-level CTA or one of a pair
      // in a Row.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
