import 'package:flutter/material.dart';
import '../theme/glow_card.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_theme.dart';

/// One on/off preference on [SettingsScreen]. The value lives in a
/// [ValueNotifier] the app owns, so a choice survives leaving the screen
/// (until the app restarts; there is no settings endpoint yet).
class SettingsToggle {
  final String title;
  final String subtitle;
  final ValueNotifier<bool> value;
  const SettingsToggle(
      {required this.title, required this.subtitle, required this.value});
}

/// Notification preferences and an About card, identical for both apps, so
/// each passes its own [toggles]. Same shell as the other screens (PageGlow,
/// back-only AppBar, in-body heading); the toggles sit in the screen's one
/// GlowCard.
class SettingsScreen extends StatelessWidget {
  final List<SettingsToggle> toggles;
  final String appName;
  final String version;
  const SettingsScreen({
    super.key,
    required this.toggles,
    required this.appName,
    this.version = '1.0.0',
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

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Settings',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text('Choose what we tell you about.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              GlowCard(
                // GlowCard paints a background, which would hide the tiles' ink.
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      for (final t in toggles)
                        ValueListenableBuilder<bool>(
                          valueListenable: t.value,
                          builder: (_, on, __) => SwitchListTile(
                            value: on,
                            onChanged: (v) => t.value.value = v,
                            title: Text(t.title,
                                style: OneHubTextStyles.bodyText(textPrimary)
                                    .copyWith(fontWeight: FontWeight.w700)),
                            subtitle: Text(t.subtitle,
                                style: OneHubTextStyles.bodyText(textSecondary)
                                    .copyWith(fontSize: 13)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: OneHubTheme.cardPadding,
                                vertical: 4),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text('About',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(appName,
                              style: OneHubTextStyles.bodyText(textPrimary)
                                  .copyWith(fontWeight: FontWeight.w700))),
                      Text('Version $version',
                          style: OneHubTextStyles.fieldLabel(textMuted)
                              .copyWith(letterSpacing: 0, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Preferences are kept on this device only for now.',
                  textAlign: TextAlign.center,
                  style: OneHubTextStyles.fieldLabel(textMuted)
                      .copyWith(letterSpacing: 0, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
