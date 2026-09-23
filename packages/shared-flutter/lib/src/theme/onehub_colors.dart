import 'package:flutter/material.dart';

/// Brand palette shared by the customer app and provider app (mobile only —
/// admin-web keeps its own teal palette in apps/admin-web/src/theme.css for
/// now). Indigo-on-lavender, matching a reference style the user supplied
/// directly (a "PetCare" app mockup): soft, friendly, consumer-app register,
/// a deliberate departure from the earlier deep-teal "trustworthy platform"
/// look. Status colors are semantic and used directly in widgets rather than
/// mapped onto Material's primary/secondary/tertiary slots, since
/// ColorScheme has no built-in "success"/"warning" concept.
abstract final class OneHubColors {
  static const primary = Color(0xFF4F46E5); // indigo
  static const primaryDark = Color(0xFF818CF8); // lighter indigo, for dark-mode seed

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFD32F2F);

  static const surfaceLight = Color(0xFFF5F6FC); // soft lavender-white
  static const surfaceDark = Color(0xFF15162E); // deep indigo-black
  static const inputFillLight = Color(0xFFF1F2FA);
  static const inputFillDark = Color(0xFF23244A);
}
