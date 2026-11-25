import 'package:flutter/material.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_theme.dart';

/// The code from an OTP request's reply. No SMS provider is connected yet, so
/// outside production the API sends the code back (devOnlyOtp); in production
/// it never does, and this is null.
String? testCodeFrom(Map<String, dynamic> reply) => switch (reply['devOnlyOtp']) {
      final String code when code.isNotEmpty => code,
      _ => null,
    };

/// "Test code: 482913" under a code field, so a code can be typed while no
/// SMS is sent. Nothing when [code] is null, which is always the case in
/// production.
class TestCodeHint extends StatelessWidget {
  final String? code;
  const TestCodeHint(this.code, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = code;
    if (c == null) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text.rich(
        TextSpan(
          style: OneHubTextStyles.fieldLabel(muted).copyWith(letterSpacing: 0, fontSize: 12),
          children: [
            const TextSpan(text: 'Test code: '),
            TextSpan(
                text: c,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: OneHubColors.primary)),
            const TextSpan(text: ' (no SMS is sent in this test version)'),
          ],
        ),
        key: const Key('test-code'),
      ),
    );
  }
}
