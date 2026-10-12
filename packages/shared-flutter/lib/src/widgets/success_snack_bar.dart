import 'package:flutter/material.dart';
import '../theme/onehub_theme.dart';

/// A floating confirmation shown after an action went through ("Bid sent.").
///
/// Returns the [SnackBar] rather than showing it, so a screen that is about
/// to pop can grab its `ScaffoldMessenger` first and show the message on the
/// screen it returns to:
///
///     final messenger = ScaffoldMessenger.of(context);
///     final bar = successSnackBar(context, 'Request sent.');
///     Navigator.of(context).pop();
///     messenger.showSnackBar(bar);
SnackBar successSnackBar(BuildContext context, String message) {
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: context.statusSuccess,
    duration: const Duration(seconds: 3),
    content: Row(
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

/// Shows [successSnackBar] on the nearest messenger, replacing any message
/// already on screen instead of queueing behind it. Use this for actions that
/// stay on the same screen; a screen about to pop should capture its
/// messenger and call `messenger.hideCurrentSnackBar()` itself.
void showSuccessMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(successSnackBar(context, message));
}
