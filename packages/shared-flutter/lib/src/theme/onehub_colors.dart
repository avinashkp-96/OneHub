import 'package:flutter/material.dart';

/// Brand palette shared by the customer app and provider app (mobile only —
/// admin-web keeps its own teal palette in apps/admin-web/src/theme.css for
/// now). Values below are the exact tokens from a formal style guide PDF
/// the user supplied directly on 2026-09-25 ("Component library and visual
/// tokens extracted from the signup screen"), which superseded a slightly
/// different reading of the same underlying Figma file taken the day before
/// by extracting live computed CSS (close, but not byte-exact — e.g. the
/// background was read as #121714 then, #111318 per this PDF). Treat this
/// PDF as the authoritative source over any prior screenshot/CSS reading
/// when the two disagree.
abstract final class OneHubColors {
  static const primary = Color(0xFF3B82F6); // "Accent"
  static const primaryGradientEnd = Color(0xFF1D4ED8); // "Accent Hover"
  static const primaryDark = Color(0xFF60A5FA); // "Accent Text"
  static const primaryDarkGradientEnd = Color(0xFF3B82F6);

  static const accentPurple = Color(0xFFB39CFF); // "Purple"
  static const requiredAsterisk = Color(0xFFFF6B6B); // "Required"

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFD32F2F);

  // Dark is the style guide's actual, only documented mode — these are its
  // exact tokens. Light is a derived equivalent (same alpha-over-white
  // logic mirrored from alpha-over-black), not separately specified.
  static const surfaceDark = Color(0xFF111318); // "Background"
  static const cardFillDark =
      Color(0x0DFFFFFF); // "Surface": rgba(255,255,255,0.05)
  static const cardBorderDark = Color(
      0x1AFFFFFF); // ~rgba(255,255,255,0.1), not separately named in the guide
  static const inputFillDark = Color(0x0DFFFFFF);
  static const inputBorderDark = Color(0x1AFFFFFF);
  static const textPrimaryDark =
      Color(0xEBFFFFFF); // "Text Primary": rgba(255,255,255,0.92)
  static const textSecondaryDark =
      Color(0x8CFFFFFF); // "Text Secondary": rgba(255,255,255,0.55)
  static const textMutedDark =
      Color(0x59FFFFFF); // "Text Muted": rgba(255,255,255,0.35)

  static const surfaceLight = Color(0xFFF7F8FA);
  static const cardFillLight = Colors.white;
  static const cardBorderLight = Color(0x14000000);
  static const inputFillLight = Color(0xFFF1F3F6);
  static const inputBorderLight = Color(0x14000000);
  static const textPrimaryLight = Color(0xEB000000);
  static const textSecondaryLight = Color(0x8C000000);
  static const textMutedLight = Color(0x59000000);

  // GlowCard's two ambient blobs: a soft blue glow anchored bottom-left and
  // a subtle light glow anchored top-right, both clipped inside the card
  // (see glow_card.dart) — never on the page background.
  static const glowBlue1 =
      Color(0x382563EB); // rgba(37,99,235,0.22), bottom-left
  static const glowLight =
      Color(0x1FFFFFFF); // rgba(255,255,255,0.12), top-right

  // CurvedNavBar's floating bar fill — solid (not translucent like
  // cardFillDark) since it sits over arbitrary scrolling content, not a
  // fixed dark backdrop, and needs to read clearly at any scroll position.
  static const navBarFillDark = Color(0xFF1B1E24);
  static const navBarFillLight = Colors.white;
}
