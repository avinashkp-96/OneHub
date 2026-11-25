import 'package:flutter/material.dart';
import '../screens/info_screen.dart';
import '../screens/legal_content.dart';
import '../theme/onehub_theme.dart';

/// Opens the Terms & privacy page, the same one Profile links to.
void openTermsAndPrivacy(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const InfoScreen(
              title: 'Terms & privacy',
              subtitle: 'The ground rules.',
              notice: legalPlaceholderNotice,
              sections: [...onehubTermsSections, ...onehubPrivacySections],
            )));

/// "I agree to the Terms & Conditions and Privacy Policy", where both names
/// open the Terms & privacy page. Used next to the signup checkbox in both
/// apps; [privacy] false leaves the Privacy Policy part out.
class TermsAgreementText extends StatelessWidget {
  final String lead;
  final bool privacy;
  final Color textColor;
  final Color linkColor;
  const TermsAgreementText({
    super.key,
    this.lead = 'I agree to the ',
    this.privacy = true,
    required this.textColor,
    required this.linkColor,
  });

  @override
  Widget build(BuildContext context) {
    WidgetSpan link(String text, String key) => WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            key: Key(key),
            onTap: () => openTermsAndPrivacy(context),
            child: Text(text, style: OneHubTextStyles.linkText(linkColor)),
          ),
        );
    return Text.rich(
      TextSpan(
        style: OneHubTextStyles.bodyText(textColor),
        children: [
          TextSpan(text: lead),
          link('Terms & Conditions', 'terms-link'),
          if (privacy) ...[
            const TextSpan(text: ' and '),
            link('Privacy Policy', 'privacy-link'),
          ],
        ],
      ),
    );
  }
}
