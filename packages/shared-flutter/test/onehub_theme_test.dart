import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  test('light theme uses the brand seed color and Material 3', () {
    final theme = OneHubTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, isNotNull);
  });

  test('dark theme is distinct from light theme', () {
    final light = OneHubTheme.light();
    final dark = OneHubTheme.dark();
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(dark.scaffoldBackgroundColor, isNot(equals(light.scaffoldBackgroundColor)));
  });

  test('buttons get a 48px minimum height for outdoor tap targets, not forced full width', () {
    final theme = OneHubTheme.light();
    final buttonStyle = theme.filledButtonTheme.style;
    final minSize = buttonStyle?.minimumSize?.resolve({});
    expect(minSize?.height, 48);
    expect(minSize?.width, isNot(double.infinity));
  });

  testWidgets('PrimaryCta stretches to the width its parent allows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.light(),
        home: const Scaffold(
          body: SizedBox(width: 300, child: PrimaryCta(onPressed: null, child: Text('Go'))),
        ),
      ),
    );
    // find.byType(SizedBox).first would find the test's own 300px wrapper
    // (higher in the tree) instead of PrimaryCta's internal one — be explicit
    // about which SizedBox this assertion is actually about.
    final innerSizedBox = tester.widget<SizedBox>(
      find.descendant(of: find.byType(PrimaryCta), matching: find.byType(SizedBox)),
    );
    expect(innerSizedBox.width, double.infinity);
  });

  test('app bars are transparent with dark text, not a bold color bar', () {
    // Matches the reference style: a plain light background with a small
    // centered title, not a solid-color header.
    final theme = OneHubTheme.light();
    expect(theme.appBarTheme.backgroundColor, Colors.transparent);
    expect(theme.appBarTheme.foregroundColor, theme.colorScheme.onSurface);
    expect(theme.appBarTheme.centerTitle, isTrue);
  });

  test('buttons are pill-shaped per the reference, not rounded rectangles', () {
    final theme = OneHubTheme.light();
    expect(theme.filledButtonTheme.style?.shape?.resolve({}), isA<StadiumBorder>());
  });

  test('cards use a large radius and no visible border, reading as floating on the background', () {
    final theme = OneHubTheme.light();
    final shape = theme.cardTheme.shape as RoundedRectangleBorder?;
    expect(shape?.borderRadius, BorderRadius.circular(24));
    expect(shape?.side, BorderSide.none);
  });

  test('dark-mode seed uses the lighter indigo, not the same seed as light mode', () {
    final light = OneHubTheme.light();
    final dark = OneHubTheme.dark();
    expect(dark.colorScheme.primary, isNot(equals(light.colorScheme.primary)));
  });
}
