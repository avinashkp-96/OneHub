import 'package:flutter/foundation.dart';
import 'package:onehub_shared/onehub_shared.dart';

// In-memory provider settings: there is no settings endpoint yet, so these
// start from explicit dummy values, the Settings screen changes them, and they
// reset when the app restarts. The account details themselves now come from
// GET /providers/me (see the Profile screen).
final providerSettingsToggles = [
  SettingsToggle(
    title: 'New request alerts',
    subtitle: 'Tell me when a customer posts a job near me',
    value: ValueNotifier(true),
  ),
  SettingsToggle(
    title: 'Job updates',
    subtitle: 'Selections, contact unlocks and completions',
    value: ValueNotifier(true),
  ),
  SettingsToggle(
    title: 'Offers and tips',
    subtitle: 'Plan renewals and ways to win more jobs',
    value: ValueNotifier(false),
  ),
];
