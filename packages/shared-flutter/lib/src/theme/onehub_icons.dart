import 'package:flutter/widgets.dart';

/// Single source of truth for which icon (and which weight) means what,
/// across both apps. Sticking to one family (Iconly) and one weight
/// (Light, matching the reference's thin single-stroke look) everywhere
/// keeps icon style/stroke/weight consistent app-wide — pick from here
/// instead of defining a new icon constant directly, so a future style
/// change happens in one place.
///
/// Defined as plain `IconData` constants against the bundled
/// assets/fonts/IconlyLight.ttf / IconlyBold.ttf (declared in this
/// package's pubspec.yaml), not through the `iconly` or `flutter_iconly`
/// pub packages — both subclass `IconData`, which became a `final class`
/// in this Flutter version, so neither compiles. Codepoints below were
/// read directly out of the `iconly` package's (MIT-licensed) source next
/// to its font files, not guessed. See assets/fonts/IconlyFont-LICENSE.txt.
///
/// Two deliberate exceptions to the "always Light" rule, both because the
/// UI pattern itself needs a filled/outline distinction to read correctly:
/// rating stars (filled vs. empty) and the signup success checkmark (wants
/// more visual weight at large size). Both still stay within the Iconly
/// family for stroke-family consistency.
abstract final class OneHubIcons {
  static const double size = 20;

  static const _lightFamily = 'IconlyLight';
  static const _boldFamily = 'IconlyBold';
  static const _package = 'onehub_shared';

  // Auth / form fields
  static const user = IconData(0xe949,
      fontFamily: _lightFamily, fontPackage: _package); // profile
  static const phone =
      IconData(0xe91b, fontFamily: _lightFamily, fontPackage: _package); // call
  static const email = IconData(0xe93c,
      fontFamily: _lightFamily, fontPackage: _package); // message
  static const lock =
      IconData(0xe939, fontFamily: _lightFamily, fontPackage: _package);
  static const confirmed = IconData(0xe94e,
      fontFamily: _lightFamily, fontPackage: _package); // shield_done
  static const location =
      IconData(0xe938, fontFamily: _lightFamily, fontPackage: _package);
  static const show =
      IconData(0xe950, fontFamily: _lightFamily, fontPackage: _package);
  static const hide =
      IconData(0xe932, fontFamily: _lightFamily, fontPackage: _package);

  // Navigation
  static const home =
      IconData(0xe933, fontFamily: _lightFamily, fontPackage: _package);
  static const search =
      IconData(0xe94b, fontFamily: _lightFamily, fontPackage: _package);
  static const documentList = IconData(0xe928,
      fontFamily: _lightFamily, fontPackage: _package); // document
  static const notification =
      IconData(0xe93f, fontFamily: _lightFamily, fontPackage: _package);
  static const profile =
      IconData(0xe949, fontFamily: _lightFamily, fontPackage: _package);
  static const wallet =
      IconData(0xe962, fontFamily: _lightFamily, fontPackage: _package);
  static const work =
      IconData(0xe963, fontFamily: _lightFamily, fontPackage: _package);
  static const chevronRight = IconData(0xe90d,
      fontFamily: _lightFamily, fontPackage: _package); // arrow_right_2
  static const chevronDown = IconData(0xe903,
      fontFamily: _lightFamily, fontPackage: _package); // arrow_down_2
  static const arrowLeft = IconData(0xe908,
      fontFamily: _lightFamily, fontPackage: _package); // arrow_left_2

  // Misc
  static const category =
      IconData(0xe920, fontFamily: _lightFamily, fontPackage: _package);
  static const plus =
      IconData(0xe948, fontFamily: _lightFamily, fontPackage: _package);
  static const calendar =
      IconData(0xe91a, fontFamily: _lightFamily, fontPackage: _package);
  static const filter =
      IconData(0xe92c, fontFamily: _lightFamily, fontPackage: _package);

  // Service categories — Iconly has no trade-specific glyphs (electrician,
  // plumber, etc.), so these are the closest general-purpose icons in the
  // set rather than a literal match.
  static const danger = IconData(0xe924,
      fontFamily: _lightFamily, fontPackage: _package); // electrician
  static const edit = IconData(0xe92a,
      fontFamily: _lightFamily, fontPackage: _package); // painter

  // Deliberate exceptions — see class doc.
  static const starFilled =
      IconData(0xe951, fontFamily: _boldFamily, fontPackage: _package);
  static const starOutline =
      IconData(0xe951, fontFamily: _lightFamily, fontPackage: _package);
  static const successCheck = IconData(0xe953,
      fontFamily: _boldFamily, fontPackage: _package); // tick_square
}
