import 'package:flutter/material.dart';
import '../theme/glow_card.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_theme.dart';

/// A headed block of text on [InfoScreen].
class InfoSection {
  final String heading;
  final String body;
  const InfoSection(this.heading, this.body);
}

/// A read-only text page (terms, privacy policy), identical for both apps.
/// Same shell as the other screens (PageGlow, page title in the AppBar); the sections sit in the screen's one GlowCard. [notice], when
/// given, shows above the sections, so placeholder text can say it is
/// placeholder.
class InfoScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<InfoSection> sections;
  final String? notice;
  const InfoScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.sections,
    this.notice,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: Text(title)),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text(subtitle, style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              if (notice != null) ...[
                Text(notice!,
                    style: OneHubTextStyles.bodyText(context.statusWarning)),
                const SizedBox(height: 16),
              ],
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < sections.length; i++) ...[
                        if (i > 0) const SizedBox(height: 20),
                        Text(sections[i].heading,
                            style: OneHubTextStyles.pageHeading(textPrimary)
                                .copyWith(fontSize: 17)),
                        const SizedBox(height: 6),
                        Text(sections[i].body,
                            style: OneHubTextStyles.bodyText(textSecondary)),
                      ],
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
