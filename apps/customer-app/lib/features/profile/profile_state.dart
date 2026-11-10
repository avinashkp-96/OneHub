import 'package:flutter/foundation.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';

// The signed-in customer's account, from GET /users/me. Null until loaded;
// the dashboard greeting and the Profile screen both listen to it, and Edit
// profile saves through PATCH /users/me. Logging out clears it, so the next
// account never sees the previous one's details.
final customerProfile = ValueNotifier<ProfileDetails?>(null);

ProfileDetails _fromJson(Map<String, dynamic> json) => ProfileDetails(
      name: json['fullName'] as String? ?? '',
      phone: phoneLabel(json['mobile'] as String? ?? ''),
      email: json['email'] as String? ?? '',
    );

/// "9000000001" as "+91 90000 00001"; anything else as it is.
String phoneLabel(String mobile) => mobile.length == 10
    ? '+91 ${mobile.substring(0, 5)} ${mobile.substring(5)}'
    : mobile;

Future<void> loadCustomerProfile() async {
  final json = await api.get('/users/me') as Map<String, dynamic>;
  customerProfile.value = _fromJson(json);
}

/// Saves the name and email; an empty email clears it. Throws the API's
/// message (for example "email already in use") so Edit profile can show it.
Future<void> saveCustomerProfile(String name, String email) async {
  try {
    final json = await api.patch(
        '/users/me', {'fullName': name, 'email': email.isEmpty ? null : email},
        auth: true);
    customerProfile.value = _fromJson(json);
  } on ApiException catch (e) {
    throw e.message;
  }
}

// Notification preferences have no settings endpoint yet, so these start from
// fixed values, Settings changes them, and they reset when the app restarts.
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
