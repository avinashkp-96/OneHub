import 'package:onehub_shared/onehub_shared.dart';

// Explicit dummy data: there is no notifications endpoint yet. The screen
// itself is shared (onehub_shared's NotificationsScreen); replace this list
// with a fetch when the API exists.
const dummyProviderNotifications = [
  OneHubNotification(
    title: 'New request nearby',
    body: 'Ceiling fan making a rattling noise, 2.1 km away.',
    timeLabel: '5 min ago',
    icon: OneHubIcons.work,
    unread: true,
  ),
  OneHubNotification(
    title: 'You were selected',
    body: 'Meera confirmed you for "Install two ceiling lights".',
    timeLabel: '1 hour ago',
    icon: OneHubIcons.confirmed,
    unread: true,
  ),
  OneHubNotification(
    title: 'Contact unlocked',
    body: "You can now call or message Ravi about the fuse box job.",
    timeLabel: 'Yesterday',
    icon: OneHubIcons.wallet,
  ),
  OneHubNotification(
    title: 'Certification progress',
    body: "You're 3 of 5 steps in. Next up: reach a 4.0 rating.",
    timeLabel: '2 days ago',
    icon: OneHubIcons.successCheck,
  ),
];
