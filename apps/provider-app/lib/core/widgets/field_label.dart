import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';

/// Small uppercase field label ("MOBILE NUMBER OR EMAIL"), with an optional
/// leading icon and "required" asterisk. Mirrors the customer app's
/// `core/widgets/field_label.dart` — duplicated rather than shared, since
/// promoting it is a review-time decision (see REUSABILITY_LOG.md).
class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  final IconData? icon;
  const FieldLabel(this.text, {super.key, this.required = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final style = OneHubTextStyles.fieldLabel(color);
    final label = required
        ? Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(text: text),
                const TextSpan(
                    text: ' *',
                    style: TextStyle(color: OneHubColors.requiredAsterisk)),
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
