import 'package:flutter/material.dart';
import 'onehub_colors.dart';

/// Shared Material 3 theme for the customer and provider apps. Both apps
/// should use this instead of building their own ThemeData, so a palette or
/// typography change only has to happen in one place.
///
/// Style reference: a Figma Make prototype the user linked directly, read
/// at its "Version 5" iteration (2026-09-24) by extracting computed CSS
/// from the live rendered page, not by eyeballing a screenshot — see
/// OneHubColors' doc comment for exact values and where each one came from.
/// Dark-first: Tailwind blue-500/700 gradient CTAs, translucent white-on-dark
/// cards and inputs with a visible ~10% white border (not the shadow-only,
/// borderless cards from an earlier reading of an older version of the same
/// file), 14px rounded-rect buttons (not a full pill), one font throughout
/// (Plus Jakarta Sans) rather than the previous two-font Outfit/Inter split.
///
/// Plus Jakarta Sans is referenced by family name rather than through the
/// `google_fonts` package: that package's runtime API fetches fonts over
/// the network with no offline fallback, which broke every widget test
/// touching this theme and would be a real production risk (a customer on
/// a bad connection shouldn't be blocked from seeing basic UI text). On
/// web, `apps/*/web/index.html` loads it via a Google Fonts stylesheet
/// `<link>`. On mobile, until the actual .ttf is bundled as an asset
/// (tracked as a known gap in CLAUDE.md), this falls back to the platform's
/// default font rather than failing.
abstract final class OneHubTheme {
  static const fontFamily = 'Plus Jakarta Sans';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: dark ? OneHubColors.primaryDark : OneHubColors.primary,
      brightness: brightness,
    );
    final textTheme = _textTheme(dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme);
    final cardBorder = dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: dark ? OneHubColors.surfaceDark : OneHubColors.surfaceLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      // Translucent surface + a visible subtle border, not a shadow-only
      // card — reads as "a panel on the dark background" rather than as a
      // Material-elevation card.
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorder),
        ),
      ),
      // 14px rounded rectangles, not a full pill — a real shape change from
      // the previous StadiumBorder reading. A fixed 48px minimum height
      // (not full width, by design — see PrimaryCta below for page-level
      // CTAs) so every button is an easy outdoor/gloved-hand tap target.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? OneHubColors.inputFillDark : OneHubColors.inputFillLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? OneHubColors.inputBorderDark : OneHubColors.inputBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? OneHubColors.inputBorderDark : OneHubColors.inputBorderLight),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
      ),
    );
  }

  /// Plus Jakarta Sans for every TextTheme slot — one font throughout,
  /// replacing the earlier Outfit/Inter split. Still set explicitly per
  /// slot rather than via ThemeData's fontFamily-default-plus-merge
  /// behavior, so it stays deterministic and trivial to unit test.
  static TextTheme _textTheme(TextTheme base) {
    TextStyle apply(TextStyle? style) => (style ?? const TextStyle()).copyWith(fontFamily: fontFamily);
    return base.copyWith(
      displayLarge: apply(base.displayLarge),
      displayMedium: apply(base.displayMedium),
      displaySmall: apply(base.displaySmall),
      headlineLarge: apply(base.headlineLarge),
      headlineMedium: apply(base.headlineMedium),
      headlineSmall: apply(base.headlineSmall),
      titleLarge: apply(base.titleLarge),
      titleMedium: apply(base.titleMedium),
      titleSmall: apply(base.titleSmall),
      bodyLarge: apply(base.bodyLarge),
      bodyMedium: apply(base.bodyMedium),
      bodySmall: apply(base.bodySmall),
      labelLarge: apply(base.labelLarge),
      labelMedium: apply(base.labelMedium),
      labelSmall: apply(base.labelSmall),
    );
  }
}

/// A page-level primary CTA ("Login", "Send Request", "Submit Bid") that
/// spans the full width available, rendered as a gradient rounded-rect with
/// a soft shadow, per the reference. Buttons used inline (e.g. Accept/Reject
/// side by side in a Row) should stay plain `FilledButton`/`OutlinedButton` —
/// forcing full width there fights the Row's layout instead of the other
/// widget in it, and the gradient look is meant to read as "the one primary
/// action on this screen," not as decoration on every button.
class PrimaryCta extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const PrimaryCta({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final gradientEnd = dark ? OneHubColors.primaryDarkGradientEnd : OneHubColors.primaryGradientEnd;
    final disabled = onPressed == null;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: disabled
              ? null
              : LinearGradient(colors: [scheme.primary, gradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: disabled ? scheme.onSurface.withValues(alpha: 0.12) : null,
          boxShadow: disabled
              ? null
              : [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Center(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: disabled ? scheme.onSurface.withValues(alpha: 0.38) : scheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(color: disabled ? scheme.onSurface.withValues(alpha: 0.38) : scheme.onPrimary),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small tinted rounded-rect badge ("NEW ACCOUNT", "GPS"), per the
/// reference — 15% tinted background, ~22% tinted border, tinted text,
/// small radius (6px, not a pill).
class TintedBadge extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const TintedBadge({super.key, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    );
    if (onTap == null) return content;
    return InkWell(borderRadius: BorderRadius.circular(6), onTap: onTap, child: content);
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
