import 'package:onehub_shared/onehub_shared.dart';

// Explicit dummy data: there is no notifications endpoint yet. The screen
// itself is shared (onehub_shared's NotificationsScreen); replace this list
// with a fetch when the API exists.
const dummyCustomerNotifications = [
  OneHubNotification(
    title: 'New bid on your request',
    body:
        'Asha Electricals bid ₹450–₹850 for "Ceiling fan making a rattling noise".',
    timeLabel: '10 min ago',
    icon: OneHubIcons.wallet,
    unread: true,
  ),
  OneHubNotification(
    title: 'A provider accepted',
    body: 'Ravi Kumar accepted your request for a leaking kitchen tap.',
    timeLabel: '1 hour ago',
    icon: OneHubIcons.confirmed,
    unread: true,
  ),
  OneHubNotification(
    title: 'How did it go?',
    body:
        'Rate the "Repaint the living room walls" job to help other customers.',
    timeLabel: 'Yesterday',
    icon: OneHubIcons.starOutline,
  ),
  OneHubNotification(
    title: 'Request expired',
    body:
        'Nobody replied to "Fix a squeaky door hinge" in time. You can post it again.',
    timeLabel: '2 days ago',
    icon: OneHubIcons.danger,
  ),
];
