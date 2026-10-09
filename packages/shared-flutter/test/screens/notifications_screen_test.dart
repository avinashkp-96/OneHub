import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  const items = [
    OneHubNotification(
      title: 'New bid',
      body: 'Asha bid on your request',
      timeLabel: '10 min ago',
      icon: OneHubIcons.wallet,
      unread: true,
    ),
    OneHubNotification(
      title: 'Request accepted',
      body: 'Ravi accepted your request',
      timeLabel: '1 h ago',
      icon: OneHubIcons.confirmed,
      unread: true,
    ),
    OneHubNotification(
      title: 'Rate your job',
      body: 'How did the repaint go?',
      timeLabel: 'Yesterday',
      icon: OneHubIcons.starOutline,
    ),
  ];

  Future<void> pumpScreen(
      WidgetTester tester, List<OneHubNotification> list) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => NotificationsScreen(items: list)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every notification with its details', (tester) async {
    await pumpScreen(tester, items);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsNothing);
    expect(find.text('Notifications'), findsOneWidget);
    for (final item in items) {
      expect(find.text(item.title), findsOneWidget, reason: item.title);
      expect(find.text(item.body), findsOneWidget, reason: item.title);
      expect(find.text(item.timeLabel), findsOneWidget, reason: item.title);
    }
  });

  testWidgets('counts the unread ones and marks them with a dot',
      (tester) async {
    await pumpScreen(tester, items);

    expect(find.text('2 unread'), findsOneWidget);
    expect(find.byKey(const Key('unread-dot')), findsNWidgets(2));
    expect(find.text('Mark all as read'), findsOneWidget);
  });

  testWidgets('tapping an unread notification marks just that one read',
      (tester) async {
    await pumpScreen(tester, items);

    await tester.tap(find.text('New bid'));
    await tester.pump();

    expect(find.text('1 unread'), findsOneWidget);
    expect(find.byKey(const Key('unread-dot')), findsOneWidget);
  });

  testWidgets('tapping an already-read notification changes nothing',
      (tester) async {
    await pumpScreen(tester, items);

    await tester.tap(find.text('Rate your job'));
    await tester.pump();

    expect(find.text('2 unread'), findsOneWidget);
  });

  testWidgets('Mark all as read clears every unread dot and the link',
      (tester) async {
    await pumpScreen(tester, items);

    await tester.tap(find.text('Mark all as read'));
    await tester.pump();

    expect(find.text("You're all caught up."), findsOneWidget);
    expect(find.byKey(const Key('unread-dot')), findsNothing);
    expect(find.text('Mark all as read'), findsNothing);
  });

  testWidgets('starts caught up when nothing is unread', (tester) async {
    await pumpScreen(tester, [items.last]);

    expect(find.text("You're all caught up."), findsOneWidget);
    expect(find.text('Mark all as read'), findsNothing);
  });

  testWidgets('shows an empty state when there are no notifications',
      (tester) async {
    await pumpScreen(tester, const []);

    expect(find.text('No notifications yet.'), findsOneWidget);
  });

  testWidgets('the back button returns to the previous screen', (tester) async {
    await pumpScreen(tester, items);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen), findsNothing);
  });
}
