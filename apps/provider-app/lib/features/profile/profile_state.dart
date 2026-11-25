import 'package:flutter/foundation.dart';
import 'package:onehub_shared/onehub_shared.dart';

// Notification switches, saved on the account through /users/me/settings
// (the Settings screen loads and saves them). The API skips notifications the
// provider turned off: New request alerts covers new requests, Job updates
// selection, contact unlocks, completions and ratings. Nothing sends offers
// yet. The account details themselves come from GET /providers/me.
final providerSettingsToggles = [
  SettingsToggle(
    key: 'newRequests',
    title: 'New request alerts',
    subtitle: 'Tell me when a customer posts a job near me',
    value: ValueNotifier(true),
  ),
  SettingsToggle(
    key: 'jobUpdates',
    title: 'Job updates',
    subtitle: 'Selections, contact unlocks and completions',
    value: ValueNotifier(true),
  ),
  SettingsToggle(
    key: 'offers',
    title: 'Offers and tips',
    subtitle: 'Plan renewals and ways to win more jobs',
    value: ValueNotifier(false),
  ),
];
