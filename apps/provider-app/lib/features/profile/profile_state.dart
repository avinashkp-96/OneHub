import 'package:flutter/foundation.dart';
import 'package:onehub_shared/onehub_shared.dart';

// In-memory provider account state: there is no profile or settings endpoint
// yet, so these start from explicit dummy values, Edit profile and Settings
// change them, and they reset when the app restarts. Replace with a fetch and
// save when the API exists.
final providerProfile = ValueNotifier<ProfileDetails>(const ProfileDetails(
  name: 'Asha Electricals',
  phone: '+91 98765 12345',
  email: 'asha@example.com',
));

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
