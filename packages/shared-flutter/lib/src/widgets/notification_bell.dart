import 'package:flutter/material.dart';
import '../api_client.dart';
import '../screens/notifications_screen.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_icons.dart';
import '../theme/onehub_theme.dart';

/// The bell in both dashboards' header. Opens [NotificationsScreen] and shows
/// a red dot only while the signed-in user has unread notifications, checked
/// when the bell is built and again on return from the list. If the check
/// fails the dot stays hidden rather than guessing.
class NotificationBell extends StatefulWidget {
  final ApiClient api;
  const NotificationBell({super.key, required this.api});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final json = await widget.api.get('/notifications') as List;
      final hasUnread =
          json.any((n) => (n as Map<String, dynamic>)['readAt'] == null);
      if (mounted) setState(() => _hasUnread = hasUnread);
    } catch (_) {
      if (mounted) setState(() => _hasUnread = false);
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NotificationsScreen(api: widget.api)));
    if (mounted) _check();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardFill =
        dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final cardBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cardFill,
              border: Border.all(color: cardBorder)),
          child: IconButton(
            tooltip: _hasUnread ? 'Notifications, unread' : 'Notifications',
            padding: EdgeInsets.zero,
            icon: Icon(OneHubIcons.notification, size: 18, color: textMuted),
            onPressed: _open,
          ),
        ),
        if (_hasUnread)
          Positioned(
            top: 2,
            right: 4,
            child: Container(
              key: const Key('bell-unread-dot'),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.statusDanger,
                border: Border.all(
                    color: dark
                        ? OneHubColors.surfaceDark
                        : OneHubColors.surfaceLight,
                    width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
