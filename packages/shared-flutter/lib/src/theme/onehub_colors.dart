import 'package:flutter/material.dart';

/// Brand palette shared by the customer app, provider app, and (as CSS
/// custom properties) admin-web. Deep teal-blue reads as "trustworthy
/// service platform" to the same audience Urban Company / JustDial already
/// trained; status colors are semantic and used directly in widgets rather
/// than mapped onto Material's primary/secondary/tertiary slots, since
/// ColorScheme has no built-in "success"/"warning" concept.
abstract final class OneHubColors {
  static const primary = Color(0xFF0E7C86); // deep teal-blue
  static const primaryDark = Color(0xFF4FD3DE);

  static const success = Color(0xFF2E7D32); // confirmed / earnings
  static const warning = Color(0xFFF59E0B); // pending / awaiting selection
  static const danger = Color(0xFFD32F2F); // rejected / expired

  static const surfaceLight = Color(0xFFF7F9F9);
  static const surfaceDark = Color(0xFF101414);
}
