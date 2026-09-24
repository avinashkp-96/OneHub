import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  testWidgets('the bar is a solid, opaque, fully-rounded pill (no blur)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        home: const Scaffold(
          bottomNavigationBar: CurvedNavBar(
            items: [
              CurvedNavItem(icon: OneHubIcons.home, label: 'Home'),
              CurvedNavItem(icon: OneHubIcons.documentList, label: 'Requests'),
              CurvedNavItem(icon: OneHubIcons.profile, label: 'Profile'),
            ],
            selectedIndex: 0,
            onSelected: _noop,
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing,
        reason: 'the reference bar is solid, not blurred');

    final bar = tester.widget<Container>(find.byType(Container).first);
    final decoration = bar.decoration as BoxDecoration;
    expect(decoration.color, isNotNull);
    expect(
      decoration.color!.a,
      1.0,
      reason:
          'the bar fill must be fully opaque per the reference, not translucent',
    );
    expect(decoration.borderRadius,
        BorderRadius.circular(OneHubTheme.radiusPillBadge));
  });

  testWidgets('only the selected tab is white; its label is never painted',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        home: const Scaffold(
          bottomNavigationBar: CurvedNavBar(
            items: [
              CurvedNavItem(icon: OneHubIcons.home, label: 'Home'),
              CurvedNavItem(icon: OneHubIcons.documentList, label: 'Requests'),
              CurvedNavItem(icon: OneHubIcons.profile, label: 'Profile'),
            ],
            selectedIndex: 0,
            onSelected: _noop,
          ),
        ),
      ),
    );

    // Icon-only per the reference — no label text is ever painted, even for
    // the selected tab (unlike the earlier label-on-select design).
    expect(find.text('Home'), findsNothing);

    final homeIcon = tester.widget<Icon>(find.byIcon(OneHubIcons.home));
    expect(homeIcon.color, Colors.white);
    final requestsIcon =
        tester.widget<Icon>(find.byIcon(OneHubIcons.documentList));
    expect(requestsIcon.color, isNot(Colors.white));
  });

  testWidgets('tapping an item calls onSelected with its index',
      (tester) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        home: Scaffold(
          bottomNavigationBar: CurvedNavBar(
            items: const [
              CurvedNavItem(icon: OneHubIcons.home, label: 'Home'),
              CurvedNavItem(icon: OneHubIcons.documentList, label: 'Requests'),
            ],
            selectedIndex: 0,
            onSelected: (i) => tapped = i,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(OneHubIcons.documentList));
    expect(tapped, 1);
  });
}

void _noop(int _) {}
