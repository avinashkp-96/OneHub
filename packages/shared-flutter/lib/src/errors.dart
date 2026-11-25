import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'theme/onehub_theme.dart';

// What the user reads when something fails. Never a status code, a class
// name or "request failed": the API's own reason when it gives one, worded
// as a sentence, else a plain line about what to do.

/// API reasons that read better reworded. Anything else the API says is shown
/// as it is, as a sentence.
const _reworded = {
  'mobile number already registered':
      'This mobile number is already registered. Log in instead.',
  'invalid or expired OTP': 'That code is wrong or has expired. Request a new one.',
  'invalid credentials': 'The mobile number, email or password is wrong.',
  'account is pending verification':
      'Your account is waiting for verification. We will let you know when it is approved.',
  'email already in use': 'Another account already uses this email.',
  'no account for that mobile/email': 'No account uses that mobile number or email.',
  'mobile must be exactly 10 digits': 'Enter a 10-digit mobile number.',
  'pincode must be a 6-digit PIN code': 'Enter a 6-digit PIN code.',
  'choose where your business is': 'Choose where your business is.',
  'password and confirmPassword must match': 'The passwords do not match.',
  'newPassword and confirmNewPassword must match': 'The passwords do not match.',
  'name cannot be empty': 'Enter your name.',
  'title must not be blank': 'Add a title.',
  'house or flat is required': 'Enter the house or flat number.',
  'street and area are required': 'Enter the street and area.',
  'choose one of your saved addresses': 'Choose the address for this job.',
};

const serverTroubleMessage =
    'Something went wrong on our side. Please try again in a moment.';
const offlineMessage =
    'Could not reach OneHub. Check your internet connection and try again.';

/// [error] as one sentence the user can act on.
String userMessage(Object error) {
  if (error is ApiException) {
    final reason = error.message.trim();
    if (error.statusCode >= 500 ||
        reason.isEmpty ||
        reason == 'request failed' ||
        reason == 'upload failed') {
      return serverTroubleMessage;
    }
    return _known(reason) ?? _sentence(reason);
  }
  if (error is http.ClientException || error is TimeoutException) {
    return offlineMessage;
  }
  if (error is String && error.trim().isNotEmpty) {
    return _known(error.trim()) ?? _sentence(error.trim());
  }
  return 'Something went wrong. Please try again.';
}

/// Which form field an API refusal is about: the first key of [fields] whose
/// words appear in its reason ({'mobile': ['mobile'], 'otp': ['otp', 'code']}).
/// Null for anything else (no connection, a server fault), which belongs above
/// the form instead.
String? errorField(Object error, Map<String, List<String>> fields) {
  final reason = switch (error) {
    ApiException(:final message, :final statusCode) when statusCode < 500 =>
      message.toLowerCase(),
    String s => s.toLowerCase(),
    _ => null,
  };
  if (reason == null) return null;
  for (final entry in fields.entries) {
    if (entry.value.any((w) => reason.contains(w.toLowerCase()))) {
      return entry.key;
    }
  }
  return null;
}

// A reworded reason, matched without regard to case.
String? _known(String reason) {
  final r = reason.toLowerCase();
  for (final e in _reworded.entries) {
    if (e.key.toLowerCase() == r) return e.value;
  }
  return null;
}

String _sentence(String s) {
  final first = s[0].toUpperCase() + s.substring(1);
  return RegExp(r'[.!?]$').hasMatch(first) ? first : '$first.';
}

/// The red line under a control that is not a text field (a picker, a list
/// of choices, a checkbox), matching a text field's own error text. Nothing
/// when [text] is null.
class FieldError extends StatelessWidget {
  final String? text;
  const FieldError(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = text;
    if (t == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(t,
          style: TextStyle(color: context.statusDanger, fontSize: 12)),
    );
  }
}
