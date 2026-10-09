import 'package:flutter/foundation.dart';
import 'package:onehub_shared/onehub_shared.dart';

// In-memory customer account state: there is no profile or settings endpoint
// yet, so these start from explicit dummy values (the same "Meera" the
// dashboard greets), Edit profile and Settings change them, and they reset
// when the app restarts. Replace with a fetch and save when the API exists.
final customerProfile = ValueNotifier<ProfileDetails>(const ProfileDetails(
  name: 'Meera Nair',
  phone: '+91 98765 43210',
  email: 'meera@example.com',
));

final customerSettingsToggles = [
  SettingsToggle(
    title: 'Request updates',
    subtitle: 'New bids, confirmations and completions',
    value: ValueNotifier(true),
  ),
  SettingsToggle(
    title: 'Reminders',
    subtitle: 'Nudges to rate a finished job',
    value: ValueNotifier(true),
  ),
  SettingsToggle(
    title: 'Offers and tips',
    subtitle: 'Discounts and seasonal service reminders',
    value: ValueNotifier(false),
  ),
];
