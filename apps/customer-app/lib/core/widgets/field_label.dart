import 'package:flutter/material.dart';

/// Small uppercase field label ("FULL NAME", "MOBILE NUMBER"), per the
/// Figma reference. Shared between login_screen.dart and signup_screen.dart.
class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const FieldLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    if (!required) return Text(text, style: style);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text),
          TextSpan(text: ' *', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
    );
  }
}
