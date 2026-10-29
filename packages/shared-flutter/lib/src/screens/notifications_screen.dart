import 'package:flutter/material.dart';
import '../api_client.dart';
import '../theme/glow_card.dart';
import '../theme/onehub_colors.dart';
import '../theme/onehub_icons.dart';
import '../theme/onehub_theme.dart';

/// One entry in the notifications list, from GET /notifications. The API
/// stores an event name and a message (docx section 6, Notification Matrix);
/// the title and icon shown here are derived from the event.
class OneHubNotification {
  final String id;
  final String event;
  final String body;
  final DateTime createdAt;
  final bool unread;
  const OneHubNotification({
    required this.id,
    required this.event,
    required this.body,
    required this.createdAt,
    this.unread = false,
  });

  factory OneHubNotification.fromJson(Map<String, dynamic> json) =>
      OneHubNotification(
        id: json['id'] as String,
        event: json['event'] as String,
        body: json['message'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        unread: json['readAt'] == null,
      );

  String get title => _titles[event] ?? 'Notification';
  IconData get icon => _icons[event] ?? OneHubIcons.notification;

  static const _titles = {
    'NEW_REQUEST': 'New job request',
    'REQUEST_ACCEPTED': 'Request accepted',
    'BID_RECEIVED': 'New bid',
    'CONTACT_UNLOCKED': 'Contact unlocked',
    'BID_UPDATED': 'Bid updated',
    'SELECTED': "You've been selected",
    'NOT_SELECTED': 'Job assigned elsewhere',
    'JOB_COMPLETED': 'Job completed',
    'NEW_RATING': 'New rating',
    'CERTIFIED': 'Certified provider',
  };

  static const _icons = {
    'NEW_REQUEST': OneHubIcons.work,
    'REQUEST_ACCEPTED': OneHubIcons.confirmed,
    'BID_RECEIVED': OneHubIcons.wallet,
    'CONTACT_UNLOCKED': OneHubIcons.lock,
    'BID_UPDATED': OneHubIcons.wallet,
    'SELECTED': OneHubIcons.confirmed,
    'NOT_SELECTED': OneHubIcons.danger,
    'JOB_COMPLETED': OneHubIcons.starOutline,
    'NEW_RATING': OneHubIcons.starOutline,
    'CERTIFIED': OneHubIcons.confirmed,
  };
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Just now", "5 min ago", "2 hours ago", "Yesterday", "3 days ago", then a
/// date ("12 Oct").
String relativeTimeLabel(DateTime time, DateTime now) {
  final age = now.difference(time);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inMinutes < 60) return '${age.inMinutes} min ago';
  if (age.inHours < 24) {
    return age.inHours == 1 ? '1 hour ago' : '${age.inHours} hours ago';
  }
  if (age.inDays < 2) return 'Yesterday';
  if (age.inDays < 7) return '${age.inDays} days ago';
  return '${time.day} ${_months[time.month - 1]}';
}

/// Notifications list, identical for the customer and provider apps, so it
/// lives here and each app passes its own [api]. Matches the other
/// redesigned screens (PageGlow, page title in the AppBar, bordered tiles).
/// Unread items carry a primary-coloured border and a dot; tapping one marks
/// it read and "Mark all as read" clears the rest, both saved through the API.
/// Pull down to refresh.
class NotificationsScreen extends StatefulWidget {
  final ApiClient api;

  /// Clock for the time labels; tests pass a fixed one. Defaults to now.
  final DateTime Function()? clock;

  const NotificationsScreen({super.key, required this.api, this.clock});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<OneHubNotification> _items = [];
  final Set<String> _read = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await widget.api.get('/notifications') as List;
      if (!mounted) return;
      setState(() {
        _items = json
            .map((n) => OneHubNotification.fromJson(n as Map<String, dynamic>))
            .toList();
        _read
          ..clear()
          ..addAll(_items.where((n) => !n.unread).map((n) => n.id));
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load notifications: $e';
        _loading = false;
      });
    }
  }

  int get _unreadCount => _items.where((n) => !_read.contains(n.id)).length;

  // Marked read on screen straight away; the save happens in the background
  // and a failed one is simply retried next time the list loads.
  void _markRead(OneHubNotification n) {
    if (_read.contains(n.id)) return;
    setState(() => _read.add(n.id));
    widget.api
        .patch('/notifications/${n.id}/read', {}, auth: true)
        .catchError((_) => <String, dynamic>{});
  }

  void _markAllRead() {
    setState(() => _read.addAll(_items.map((n) => n.id)));
    widget.api
        .patch('/notifications/read-all', {}, auth: true)
        .catchError((_) => <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final primary = Theme.of(context).colorScheme.primary;
    final now = (widget.clock ?? DateTime.now)();

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Notifications')),
      body: PageGlow(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: OneHubTheme.pageMargin, vertical: 8),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Text(_error!, style: TextStyle(color: context.statusDanger))
                else ...[
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
                          onTap: _markAllRead,
                          child: Text('Mark all as read',
                              style: OneHubTextStyles.linkText(primary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: OneHubTheme.sectionGap),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No notifications yet.',
                          style:
                              OneHubTextStyles.bodyText(context.statusWarning)),
                    )
                  else
                    for (final n in _items)
                      _NotificationTile(
                        item: n,
                        timeLabel: relativeTimeLabel(n.createdAt, now),
                        unread: !_read.contains(n.id),
                        onTap: () => _markRead(n),
                      ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final OneHubNotification item;
  final String timeLabel;
  final bool unread;
  final VoidCallback onTap;
  const _NotificationTile(
      {required this.item,
      required this.timeLabel,
      required this.unread,
      required this.onTap});

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
                    Text(timeLabel,
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
