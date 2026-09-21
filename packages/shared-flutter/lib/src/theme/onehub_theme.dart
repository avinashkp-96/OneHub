import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'onehub_colors.dart';

/// Shared Material 3 theme for the customer and provider apps. Both apps
/// should use this instead of building their own ThemeData, so a palette or
/// typography change only has to happen in one place.
///
/// Noto Sans over Roboto/Inter: this app's provider base spans Indian cities
/// and regional-language UI is a near-term ask, not a hypothetical, so the
/// font needs Devanagari/regional-script coverage from day one rather than a
/// swap later.
abstract final class OneHubTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: OneHubColors.primary,
      brightness: brightness,
    );
    final textTheme = GoogleFonts.notoSansTextTheme(
      brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: brightness == Brightness.dark ? OneHubColors.surfaceDark : OneHubColors.surfaceLight,
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48), // one clear primary CTA per screen, easy to tap outdoors
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant.withOpacity(0.4),
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

/// Semantic status colors for request/bid/job states (docx sections 4.4-4.6,
/// 5.4-5.6): confirmed/completed reads success, pending/awaiting reads
/// warning, rejected/expired reads danger. Kept separate from ColorScheme
/// because Material 3 has no built-in success/warning slot.
extension OneHubStatusColors on BuildContext {
  Color get statusSuccess => OneHubColors.success;
  Color get statusWarning => OneHubColors.warning;
  Color get statusDanger => OneHubColors.danger;
}
