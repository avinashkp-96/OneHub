import 'package:flutter/material.dart';

/// Brand palette shared by the customer app and provider app (mobile only —
/// admin-web keeps its own teal palette in apps/admin-web/src/theme.css for
/// now). Purple-on-white, matching a Figma Make reference the user supplied
/// directly for the signup screen (exact accent: #6C63FF). Superseded the
/// earlier indigo-on-lavender "PetCare" reference on 2026-09-23 for the same
/// reason that one superseded teal: a newer, more specific reference took
/// priority. Status colors are semantic and used directly in widgets rather
/// than mapped onto Material's primary/secondary/tertiary slots, since
/// ColorScheme has no built-in "success"/"warning" concept.
abstract final class OneHubColors {
  static const primary = Color(0xFF6C63FF); // exact accent from the Figma reference
  static const primaryGradientEnd = Color(0xFF5A4FCF); // deeper purple, for the CTA gradient
  static const primaryDark = Color(0xFF9D97FF); // lighter purple, for dark-mode seed
  static const primaryDarkGradientEnd = Color(0xFF7C6FF5);

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFD32F2F);

  static const surfaceLight = Color(0xFFF7F7FB); // near-white, matching the reference
  static const surfaceDark = Color(0xFF15162E);
  static const inputFillLight = Color(0xFFF5F5F8); // slightly gray field fill, per reference
  static const inputFillDark = Color(0xFF23244A);
}
