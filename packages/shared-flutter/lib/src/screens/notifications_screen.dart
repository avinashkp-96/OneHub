import 'package:flutter/material.dart';
import '../theme/glow_card.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_theme.dart';

/// One entry in the notifications list. [timeLabel] is display text such as
/// "10 min ago"; there is no notifications API yet, so the apps feed this
/// screen explicit dummy items.
class OneHubNotification {
  final String title;
  final String body;
  final String timeLabel;
  final IconData icon;
  final bool unread;
  const OneHubNotification({
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.icon,
    this.unread = false,
  });
}

/// Notifications list, identical for the customer and provider apps, so it
/// lives here and each app passes its own [items]. Matches the other
/// redesigned screens (PageGlow, back-only AppBar plus in-body heading,
/// bordered tiles). Unread items carry a primary-coloured border and a dot;
/// tapping one marks it read, and "Mark all as read" clears the rest. Read
/// state is kept on this screen only, since nothing persists it yet.
class NotificationsScreen extends StatefulWidget {
  final List<OneHubNotification> items;
  const NotificationsScreen({super.key, required this.items});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Set<int> _read = {
    for (var i = 0; i < widget.items.length; i++)
      if (!widget.items[i].unread) i,
  };

  int get _unreadCount => widget.items.length - _read.length;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Notifications',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _unreadCount == 0
                          ? "You're all caught up."
                          : '$_unreadCount unread',
                      style: OneHubTextStyles.bodyText(textSecondary),
                    ),
                  ),
                  if (_unreadCount > 0)
                    GestureDetector(
                      onTap: () => setState(() => _read.addAll(
                          List.generate(widget.items.length, (i) => i))),
                      child: Text('Mark all as read',
                          style: OneHubTextStyles.linkText(primary)),
                    ),
                ],
              ),
              const SizedBox(height: OneHubTheme.sectionGap),
              if (widget.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No notifications yet.',
                      style: OneHubTextStyles.bodyText(context.statusWarning)),
                )
              else
                for (var i = 0; i < widget.items.length; i++)
                  _NotificationTile(
                    item: widget.items[i],
                    unread: !_read.contains(i),
                    onTap: () => setState(() => _read.add(i)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final OneHubNotification item;
  final bool unread;
  final VoidCallback onTap;
  const _NotificationTile(
      {required this.item, required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final iconFill =
        dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final border =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        side: BorderSide(color: unread ? OneHubColors.primary : border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconFill,
                    border: Border.all(color: border)),
                child: Icon(item.icon,
                    size: 18, color: unread ? OneHubColors.primary : textMuted),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: OneHubTextStyles.bodyText(textPrimary)
                                .copyWith(
                                    fontWeight: unread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    fontSize: 15),
                          ),
                        ),
                        if (unread)
                          Container(
                            key: const Key('unread-dot'),
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: OneHubColors.primary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.body,
                        style: OneHubTextStyles.bodyText(textSecondary)
                            .copyWith(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(item.timeLabel,
                        style: OneHubTextStyles.fieldLabel(textMuted)
                            .copyWith(letterSpacing: 0, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
