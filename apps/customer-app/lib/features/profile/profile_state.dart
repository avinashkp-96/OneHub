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
      photoUrl: switch (json['profilePhotoUrl']) {
        final String url => api.resolve(url),
        _ => null,
      },
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

/// Uploads [photo] and makes it the account photo. Throws a message the
/// Profile screen can show.
Future<void> saveCustomerPhoto(PickedPhoto photo) async {
  try {
    final url = await api.upload('/uploads/photo', photo.bytes, photo.name);
    final json =
        await api.patch('/users/me', {'profilePhotoUrl': url}, auth: true);
    customerProfile.value = _fromJson(json);
  } on ApiException catch (e) {
    throw e.message;
  }
}

// Notification switches, saved on the account through /users/me/settings
// (the Settings screen loads and saves them). The API skips notifications the
// customer turned off: Request updates covers new and updated bids, Reminders
// the prompt to rate a finished job. Nothing sends offers yet.
final customerSettingsToggles = [
  SettingsToggle(
    key: 'requestUpdates',
    title: 'Request updates',
    subtitle: 'New bids, confirmations and completions',
    value: ValueNotifier(true),
  ),
  SettingsToggle(
    key: 'reminders',
    title: 'Reminders',
    subtitle: 'Nudges to rate a finished job',
    value: ValueNotifier(true),
  ),
  SettingsToggle(
    key: 'offers',
    title: 'Offers and tips',
    subtitle: 'Discounts and seasonal service reminders',
    value: ValueNotifier(false),
  ),
];
