import 'package:flutter/material.dart';
import 'onehub_colors.dart';

/// Shared Material 3 theme for the customer and provider apps. Both apps
/// should use this instead of building their own ThemeData, so a palette or
/// typography change only has to happen in one place.
///
/// Style reference: a Figma Make prototype the user supplied directly for
/// the signup screen — purple accent (#6C63FF exactly), Outfit for
/// headings, Inter for body copy, pill-shaped gradient CTAs with a shadow,
/// large-radius shadowed (not outlined) cards, icon-in-field text inputs.
/// Superseded an earlier "PetCare"-referenced indigo-on-lavender look on
/// 2026-09-23 — palette/typography/shape only, not a pixel clone of that
/// prototype's specific screens.
///
/// Outfit/Inter over Noto Sans: this drops the Devanagari/regional-script
/// coverage Noto Sans had, which was chosen earlier specifically for the
/// provider base's likely regional-language needs. That tradeoff wasn't
/// re-litigated here — the user handed over an explicit font spec — but
/// it's a real regression to revisit before any localization work starts
/// (tracked in CLAUDE.md).
///
/// Both fonts are referenced by family name rather than through the
/// `google_fonts` package: that package's runtime API fetches fonts over
/// the network with no offline fallback, which broke every widget test
/// touching this theme and would be a real production risk (a customer on
/// a bad connection shouldn't be blocked from seeing basic UI text). On
/// web, `apps/*/web/index.html` loads both via a Google Fonts stylesheet
/// `<link>`. On mobile, until the actual .ttf files are bundled as assets
/// (tracked as a known gap in CLAUDE.md), this falls back to the platform's
/// default font rather than failing.
abstract final class OneHubTheme {
  static const headingFontFamily = 'Outfit';
  static const bodyFontFamily = 'Inter';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: dark ? OneHubColors.primaryDark : OneHubColors.primary,
      brightness: brightness,
    );
    final textTheme = _textTheme(dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme);

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
      // Large radius + a soft shadow instead of an outline — cards read as
      // "floating" on the background rather than as bordered Material
      // containers.
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

  /// Outfit for display/headline/title slots, Inter for body/label — every
  /// slot is set explicitly rather than relying on ThemeData's fontFamily
  /// default + textTheme merge behavior, so this is deterministic and
  /// trivial to unit test.
  static TextTheme _textTheme(TextTheme base) {
    TextStyle heading(TextStyle? style) => (style ?? const TextStyle()).copyWith(fontFamily: headingFontFamily);
    TextStyle body(TextStyle? style) => (style ?? const TextStyle()).copyWith(fontFamily: bodyFontFamily);

    return base.copyWith(
      displayLarge: heading(base.displayLarge),
      displayMedium: heading(base.displayMedium),
      displaySmall: heading(base.displaySmall),
      headlineLarge: heading(base.headlineLarge),
      headlineMedium: heading(base.headlineMedium),
      headlineSmall: heading(base.headlineSmall),
      titleLarge: heading(base.titleLarge),
      titleMedium: heading(base.titleMedium),
      titleSmall: heading(base.titleSmall),
      bodyLarge: body(base.bodyLarge),
      bodyMedium: body(base.bodyMedium),
      bodySmall: body(base.bodySmall),
      labelLarge: body(base.labelLarge),
      labelMedium: body(base.labelMedium),
      labelSmall: body(base.labelSmall),
    );
  }
}

/// A page-level primary CTA ("Login", "Send Request", "Submit Bid") that
/// spans the full width available, rendered as a gradient pill with a soft
/// shadow, per the reference. Buttons used inline (e.g. Accept/Reject side
/// by side in a Row) should stay plain `FilledButton`/`OutlinedButton` —
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
          borderRadius: BorderRadius.circular(999),
          gradient: disabled
              ? null
              : LinearGradient(colors: [scheme.primary, gradientEnd], begin: Alignment.centerLeft, end: Alignment.centerRight),
          color: disabled ? scheme.onSurface.withValues(alpha: 0.12) : null,
          boxShadow: disabled
              ? null
              : [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
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

/// Semantic status colors for request/bid/job states (docx sections 4.4-4.6,
/// 5.4-5.6): confirmed/completed reads success, pending/awaiting reads
/// warning, rejected/expired reads danger. Kept separate from ColorScheme
/// because Material 3 has no built-in success/warning slot.
extension OneHubStatusColors on BuildContext {
  Color get statusSuccess => OneHubColors.success;
  Color get statusWarning => OneHubColors.warning;
  Color get statusDanger => OneHubColors.danger;
}
