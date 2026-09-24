import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';

/// Small uppercase field label ("FULL NAME", "MOBILE NUMBER"), with an
/// optional leading icon — per the style guide, icons sit next to the label
/// text above the field, not inside the field itself. Uses the style
/// guide's exact "SemiBold/10.5px, Field label caps" type style and
/// "Required" asterisk color. Shared between login_screen.dart and
/// signup_screen.dart.
class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  final IconData? icon;
  const FieldLabel(this.text, {super.key, this.required = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final style = OneHubTextStyles.fieldLabel(color);
    final label = required
        ? Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(text: text),
                const TextSpan(text: ' *', style: TextStyle(color: OneHubColors.requiredAsterisk)),
              ],
            ),
          )
        : Text(text, style: style);

    if (icon == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: OneHubTheme.gapIconLabel),
        label,
      ],
    );
  }
}
