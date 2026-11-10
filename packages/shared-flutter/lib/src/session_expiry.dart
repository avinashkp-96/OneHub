import 'package:flutter/material.dart';
import 'api_client.dart';

const sessionExpiredMessage = 'Your session expired. Please log in again.';

/// Sends the user to `/login`, with the route stack cleared, when [api]
/// reports that the saved session no longer works. Without this an expired
/// token left a signed-in screen up with every call failing behind it: blank
/// names, dashes for numbers and empty lists, with no hint why.
void sendToLoginOnSessionExpiry(
  ApiClient api,
  GlobalKey<NavigatorState> navigator,
  GlobalKey<ScaffoldMessengerState> messenger,
) {
  api.onSessionExpired = () {
    navigator.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
    messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(sessionExpiredMessage)));
  };
}
