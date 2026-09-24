import 'package:flutter/material.dart';
import 'onehub_colors.dart';

/// Shared Material 3 theme for the customer and provider apps. Both apps
/// should use this instead of building their own ThemeData, so a palette or
/// typography change only has to happen in one place.
///
/// Style reference: a formal style guide PDF the user supplied directly on
/// 2026-09-25 ("Component library and visual tokens extracted from the
/// signup screen") — exact hex/rgba color tokens, a 7-entry type scale, and
/// named spacing/radius tokens, all reproduced in [OneHubColors],
/// [OneHubTextStyles], and the radius/padding constants below rather than
/// eyeballed. This superseded a close-but-not-exact reading of the same
/// underlying Figma file taken the day before via live computed CSS (e.g.
/// the card radius was read as 16px then; the PDF specifies 20px for "Form
/// card"). Dark-first: Tailwind blue-500/700 gradient CTAs, translucent
/// white-on-dark cards/inputs with a visible border, one font throughout
/// (Plus Jakarta Sans).
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

  // Named spacing tokens, straight off the style guide's spacing grid.
  static const gapIconLabel = 6.0;
  static const gapFieldInternals = 10.0; // label -> its input
  static const gridGap = 12.0; // e.g. Password / Confirm columns
  static const fieldPaddingX = 14.0;
  static const cardPadding = 16.0;
  static const sectionGap = 20.0; // between field groups
  static const pageMargin = 24.0;
  static const pagePaddingY = 32.0;

  // Named radius tokens.
  static const radiusGpsBadge = 6.0;
  static const radiusInputField = 12.0;
  static const radiusCtaButton = 14.0;
  static const radiusFormCard = 20.0;
  static const radiusPillBadge = 99.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: dark ? OneHubColors.primaryDark : OneHubColors.primary,
      brightness: brightness,
    );
    final textTheme = _textTheme(
        dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme, dark);
    final cardBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor:
          dark ? OneHubColors.surfaceDark : OneHubColors.surfaceLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge
            ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      // Translucent surface + a visible subtle border, not a shadow-only
      // card — reads as "a panel on the dark background" rather than as a
      // Material-elevation card. Radius: style guide's "Form card" = 20px.
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusFormCard),
          side: BorderSide(color: cardBorder),
        ),
      ),
      // Style guide's "CTA button" radius = 14px, not a full pill. A fixed
      // 48px minimum height (not full width, by design — see PrimaryCta
      // below for page-level CTAs) so every button is an easy outdoor/
      // gloved-hand tap target.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusCtaButton)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusCtaButton)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusCtaButton))),
      ),
      // Style guide's "Input fields" radius = 12px, "Padding X (field)" = 14px.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            dark ? OneHubColors.inputFillDark : OneHubColors.inputFillLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInputField),
          borderSide: BorderSide(
              color: dark
                  ? OneHubColors.inputBorderDark
                  : OneHubColors.inputBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInputField),
          borderSide: BorderSide(
              color: dark
                  ? OneHubColors.inputBorderDark
                  : OneHubColors.inputBorderLight),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: fieldPaddingX, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
      ),
    );
  }

  /// Plus Jakarta Sans for every TextTheme slot — one font throughout. Still
  /// set explicitly per slot rather than via ThemeData's fontFamily-default-
  /// plus-merge behavior, so it stays deterministic and trivial to unit
  /// test. `titleMedium` is also given the style guide's "Medium/14px"
  /// input-text size/weight here, since that's the Material slot
  /// `TextField` reads its text style from by default — one change here
  /// fixes every input's text app-wide instead of setting it per field.
  static TextTheme _textTheme(TextTheme base, bool dark) {
    TextStyle apply(TextStyle? style) =>
        (style ?? const TextStyle()).copyWith(fontFamily: fontFamily);
    return base.copyWith(
      displayLarge: apply(base.displayLarge),
      displayMedium: apply(base.displayMedium),
      displaySmall: apply(base.displaySmall),
      headlineLarge: apply(base.headlineLarge),
      headlineMedium: apply(base.headlineMedium),
      headlineSmall: apply(base.headlineSmall),
      titleLarge: apply(base.titleLarge),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500, // "Medium/14px" — input text
        color:
            dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight,
      ),
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

/// The style guide's 7 named type styles, as static methods (need a text
/// color parameter since dark/light aren't otherwise distinguishable from a
/// plain TextStyle). Prefer these over generic `Theme.of(context).textTheme`
/// slots on the auth screens this style guide actually documents — the
/// Material default type scale doesn't map 1:1 onto this bespoke one.
abstract final class OneHubTextStyles {
  static TextStyle pageHeading(Color color) => TextStyle(
      fontFamily: OneHubTheme.fontFamily,
      fontSize: 36,
      fontWeight: FontWeight.w800,
      color: color);

  static TextStyle buttonLabel(Color color) => TextStyle(
      fontFamily: OneHubTheme.fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: color);

  static TextStyle linkText(Color color) => TextStyle(
      fontFamily: OneHubTheme.fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: color);

  static TextStyle bodyText(Color color) => TextStyle(
      fontFamily: OneHubTheme.fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: color);

  static TextStyle badgeLabel(Color color) => TextStyle(
      fontFamily: OneHubTheme.fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
      color: color);

  static TextStyle fieldLabel(Color color) => TextStyle(
      fontFamily: OneHubTheme.fontFamily,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      color: color);
}

/// A page-level primary CTA ("Login", "Send Request", "Submit Bid") that
/// spans the full width available, rendered as a gradient rounded-rect with
/// a soft shadow, per the style guide ("Bold/15px" button label, 14px
/// radius). Buttons used inline (e.g. Accept/Reject side by side in a Row)
/// should stay plain `FilledButton`/`OutlinedButton` — forcing full width
/// there fights the Row's layout instead of the other widget in it, and the
/// gradient look is meant to read as "the one primary action on this
/// screen," not as decoration on every button.
///
/// Gradient and label color are the exact literal tokens
/// (`OneHubColors.primary` -> `.primaryGradientEnd`, white text), not
/// `ColorScheme.primary`/`.onPrimary` — `ColorScheme.fromSeed` derives a
/// tonal-palette color from the seed, which isn't guaranteed to equal the
/// seed's own hex value, and this button's exact color is explicitly
/// specified rather than theme-derived.
class PrimaryCta extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const PrimaryCta({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onPressed == null;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(OneHubTheme.radiusCtaButton),
          gradient: disabled
              ? null
              : const LinearGradient(
                  colors: [
                    OneHubColors.primary,
                    OneHubColors.primaryGradientEnd
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: disabled ? scheme.onSurface.withValues(alpha: 0.12) : null,
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                      color: OneHubColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(OneHubTheme.radiusCtaButton),
            onTap: onPressed,
            child: Center(
              child: DefaultTextStyle.merge(
                style: OneHubTextStyles.buttonLabel(disabled
                    ? scheme.onSurface.withValues(alpha: 0.38)
                    : Colors.white),
                child: IconTheme.merge(
                  data: IconThemeData(
                      color: disabled
                          ? scheme.onSurface.withValues(alpha: 0.38)
                          : Colors.white),
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

/// A small tinted badge, per the style guide's two documented variants:
/// the default 6px-radius rectangle ("GPS badge") and the full-pill 99px
/// variant ("Pill badges" — e.g. a "New Account"/"Free Signup" tag), picked
/// via [pill]. 15% tinted background, ~22% tinted border, tinted text —
/// "Bold/11px, Label caps" per the type scale.
class TintedBadge extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool pill;
  const TintedBadge(
      {super.key,
      required this.label,
      required this.color,
      this.onTap,
      this.pill = false});

  @override
  Widget build(BuildContext context) {
    final radius =
        pill ? OneHubTheme.radiusPillBadge : OneHubTheme.radiusGpsBadge;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(label, style: OneHubTextStyles.badgeLabel(color)),
    );
    if (onTap == null) return content;
    return InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content);
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
