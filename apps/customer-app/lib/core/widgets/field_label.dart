import 'package:flutter/material.dart';

/// Small uppercase field label ("FULL NAME", "MOBILE NUMBER"), with an
/// optional leading icon — per the reference, icons sit next to the label
/// text above the field, not inside the field itself. Shared between
/// login_screen.dart and signup_screen.dart.
class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  final IconData? icon;
  const FieldLabel(this.text, {super.key, this.required = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: color,
        );
    final label = required
        ? Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(text: text),
                TextSpan(text: ' *', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          )
        : Text(text, style: style);

    if (icon == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        label,
      ],
    );
  }
}
