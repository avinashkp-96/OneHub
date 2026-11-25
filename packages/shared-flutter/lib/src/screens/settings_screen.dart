import 'package:flutter/material.dart';
import '../api_client.dart';
import '../theme/glow_card.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_theme.dart';

/// One on/off preference on [SettingsScreen]. [key] is its name in
/// GET/PATCH /users/me/settings. The value lives in a [ValueNotifier] the app
/// owns, so other screens can read it too.
class SettingsToggle {
  final String key;
  final String title;
  final String subtitle;
  final ValueNotifier<bool> value;
  const SettingsToggle(
      {required this.key,
      required this.title,
      required this.subtitle,
      required this.value});
}

/// Notification preferences and an About card, identical for both apps, so
/// each passes its own [toggles] and [api]. Same shell as the other screens
/// (PageGlow, page title in the AppBar); the toggles sit in the screen's one
/// GlowCard.
///
/// The switches are saved on the account: the screen loads them from
/// GET /users/me/settings (switches stay disabled until then, so another
/// account's values never show) and saves each flip with PATCH. A failed save
/// puts the switch back and says so. The API honours them when it sends
/// notifications.
class SettingsScreen extends StatefulWidget {
  final List<SettingsToggle> toggles;
  final ApiClient api;
  final String appName;
  final String version;
  const SettingsScreen({
    super.key,
    required this.toggles,
    required this.api,
    required this.appName,
    this.version = '1.0.0',
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loaded = false;
  String? _error;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await widget.api.get('/users/me/settings') as Map;
      for (final t in widget.toggles) {
        final v = json[t.key];
        if (v is bool) t.value.value = v;
      }
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not load your settings. Pull down to try again.');
      }
    }
  }

  Future<void> _save(SettingsToggle t, bool on) async {
    t.value.value = on;
    setState(() => _saving.add(t.key));
    try {
      await widget.api.patch('/users/me/settings', {t.key: on}, auth: true);
    } catch (_) {
      t.value.value = !on;
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Could not save that change. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(t.key));
    }
  }

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
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Settings')),
      body: PageGlow(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: OneHubTheme.pageMargin, vertical: 8),
              children: [
                Text('Choose what we tell you about.',
                    style: OneHubTextStyles.bodyText(textSecondary)),
                const SizedBox(height: OneHubTheme.sectionGap),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!,
                        style: TextStyle(color: context.statusDanger)),
                  ),
                GlowCard(
                  // GlowCard paints a background, which would hide the tiles' ink.
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        for (final t in widget.toggles)
                          ValueListenableBuilder<bool>(
                            valueListenable: t.value,
                            builder: (_, on, __) => SwitchListTile(
                              key: Key('setting-${t.key}'),
                              value: on,
                              onChanged: _loaded && !_saving.contains(t.key)
                                  ? (v) => _save(t, v)
                                  : null,
                              title: Text(t.title,
                                  style: OneHubTextStyles.bodyText(textPrimary)
                                      .copyWith(fontWeight: FontWeight.w700)),
                              subtitle: Text(t.subtitle,
                                  style:
                                      OneHubTextStyles.bodyText(textSecondary)
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
                            child: Text(widget.appName,
                                style: OneHubTextStyles.bodyText(textPrimary)
                                    .copyWith(fontWeight: FontWeight.w700))),
                        Text('Version ${widget.version}',
                            style: OneHubTextStyles.fieldLabel(textMuted)
                                .copyWith(letterSpacing: 0, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Settings are saved to your account.',
                    textAlign: TextAlign.center,
                    style: OneHubTextStyles.fieldLabel(textMuted)
                        .copyWith(letterSpacing: 0, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
