import 'package:flutter/material.dart';
import '../theme/glow_card.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_icons.dart';
import '../theme/onehub_theme.dart';

/// One question and answer on [HelpScreen].
class FaqItem {
  final String question;
  final String answer;
  const FaqItem(this.question, this.answer);
}

/// Help and support, identical for both apps, so each passes its own [faqs]
/// and the support contact details. Same shell as the other screens
/// (PageGlow, page title in the AppBar). The contact details sit in
/// the screen's one GlowCard; each FAQ is a plain bordered card that expands
/// in place. There is no support system behind this yet, so the contact
/// values the apps pass are placeholders and nothing here sends a message.
class HelpScreen extends StatelessWidget {
  final List<FaqItem> faqs;
  final String supportEmail;
  final String supportPhone;
  const HelpScreen({
    super.key,
    required this.faqs,
    required this.supportEmail,
    required this.supportPhone,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    Widget contactRow(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: textMuted),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: OneHubTextStyles.fieldLabel(textMuted))),
              Text(value,
                  style: OneHubTextStyles.bodyText(textPrimary)
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Help & support')),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Answers to common questions, and how to reach us.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CONTACT US',
                          style: OneHubTextStyles.fieldLabel(textMuted)),
                      const SizedBox(height: 8),
                      contactRow(OneHubIcons.email, 'EMAIL', supportEmail),
                      contactRow(OneHubIcons.phone, 'PHONE', supportPhone),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text('Frequently asked',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              if (faqs.isEmpty)
                Text('No questions yet.',
                    style: OneHubTextStyles.bodyText(context.statusWarning))
              else
                for (final f in faqs)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    clipBehavior: Clip.antiAlias,
                    child: Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(f.question,
                            style: OneHubTextStyles.bodyText(textPrimary)
                                .copyWith(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedAlignment: Alignment.centerLeft,
                        children: [
                          Text(f.answer,
                              style: OneHubTextStyles.bodyText(textSecondary)),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
