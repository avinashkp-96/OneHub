import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  testWidgets('CurvedNavBar blurs content behind it instead of a solid fill',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        home: Scaffold(
          bottomNavigationBar: CurvedNavBar(
            items: const [
              CurvedNavItem(icon: OneHubIcons.category, label: 'Home'),
              CurvedNavItem(icon: OneHubIcons.documentList, label: 'Requests'),
              CurvedNavItem(icon: OneHubIcons.profile, label: 'Profile'),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(ClipPath), findsOneWidget);

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
          of: find.byType(BackdropFilter), matching: find.byType(DecoratedBox)),
    );
    final tint = (decoratedBox.decoration as BoxDecoration).color;
    expect(tint, isNotNull);
    expect(
      tint!.a,
      lessThan(1.0),
      reason:
          'the tint behind the blur must be translucent, not a solid fill, so scrolled '
          'content actually shows through blurred rather than just dimmed',
    );
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
              CurvedNavItem(icon: OneHubIcons.category, label: 'Home'),
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
