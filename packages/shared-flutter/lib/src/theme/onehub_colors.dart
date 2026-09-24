import 'package:flutter/material.dart';

/// Brand palette shared by the customer app and provider app (mobile only —
/// admin-web keeps its own teal palette in apps/admin-web/src/theme.css for
/// now). Values below were extracted directly from the live rendered Figma
/// Make reference's computed CSS (not eyeballed from a screenshot) on
/// 2026-09-24, at its "Version 5" iteration — a dark-first design built on
/// Tailwind's default blue scale. Superseded an earlier lighter indigo
/// (#6C63FF) reading of the same Figma file's "Version 1", which itself
/// superseded an even earlier "PetCare"-referenced indigo-on-lavender look.
/// Each retheme took priority over the previous one at the time it arrived.
abstract final class OneHubColors {
  static const primary = Color(0xFF3B82F6); // Tailwind blue-500 — CTA gradient start, badge text
  static const primaryGradientEnd = Color(0xFF1D4ED8); // Tailwind blue-700 — CTA gradient end
  static const primaryDark = Color(0xFF60A5FA); // Tailwind blue-400 — links, badge text on dark
  static const primaryDarkGradientEnd = Color(0xFF3B82F6);

  static const accentPurple = Color(0xFFA78BFA); // Tailwind violet-400 — second badge ("FREE SIGNUP" in the reference)

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFD32F2F);

  // Dark is the reference's actual, only rendered mode — these are the exact
  // extracted values. Light is a derived equivalent, not separately
  // specified by the reference.
  static const surfaceDark = Color(0xFF121714); // exact: rgb(18, 23, 20)
  static const cardFillDark = Color(0x0DFFFFFF); // exact: rgba(255,255,255,0.05) over surfaceDark
  static const cardBorderDark = Color(0x1AFFFFFF); // exact: rgba(255,255,255,0.1)
  static const inputFillDark = Color(0x0DFFFFFF);
  static const inputBorderDark = Color(0x1AFFFFFF);

  static const surfaceLight = Color(0xFFF7F8FA);
  static const cardFillLight = Colors.white;
  static const cardBorderLight = Color(0x14000000); // ~8% black, the light-mode equivalent border
  static const inputFillLight = Color(0xFFF1F3F6);
  static const inputBorderLight = Color(0x14000000);

  // The reference's decorative background: three radial-gradient glow blobs
  // over the flat surfaceDark, extracted from computed backgroundImage.
  static const glowBlue1 = Color(0x382563EB); // rgba(37,99,235,0.22), bottom-left
  static const glowPurple = Color(0x2E503C8C); // rgba(80,60,140,0.18), top-right
  static const glowBlue2 = Color(0x472563EB); // rgba(37,99,235,0.28), bottom-center
}
