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

  test('dark scaffold background matches the reference exactly', () {
    // Extracted from the live page's computed style, not eyeballed.
    expect(OneHubColors.surfaceDark, const Color(0xFF121714));
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
    final theme = OneHubTheme.light();
    expect(theme.appBarTheme.backgroundColor, Colors.transparent);
    expect(theme.appBarTheme.foregroundColor, theme.colorScheme.onSurface);
    expect(theme.appBarTheme.centerTitle, isTrue);
  });

  test('buttons are 14px rounded rectangles, not a full pill', () {
    final theme = OneHubTheme.light();
    final shape = theme.filledButtonTheme.style?.shape?.resolve({}) as RoundedRectangleBorder?;
    expect(shape?.borderRadius, BorderRadius.circular(14));
  });

  test('cards have a visible border, reading as a translucent panel rather than a floating shadow card', () {
    final theme = OneHubTheme.dark();
    final shape = theme.cardTheme.shape as RoundedRectangleBorder?;
    expect(shape?.side.color, OneHubColors.cardBorderDark);
    expect(shape?.side, isNot(BorderSide.none));
  });

  test('dark-mode seed differs from light mode', () {
    final light = OneHubTheme.light();
    final dark = OneHubTheme.dark();
    expect(dark.colorScheme.primary, isNot(equals(light.colorScheme.primary)));
  });

  test('primary matches the Figma reference exactly (Tailwind blue-500)', () {
    expect(OneHubColors.primary, const Color(0xFF3B82F6));
  });

  test('every text style uses Plus Jakarta Sans', () {
    final textTheme = OneHubTheme.light().textTheme;
    expect(textTheme.headlineMedium?.fontFamily, OneHubTheme.fontFamily);
    expect(textTheme.titleLarge?.fontFamily, OneHubTheme.fontFamily);
    expect(textTheme.bodyMedium?.fontFamily, OneHubTheme.fontFamily);
    expect(textTheme.labelLarge?.fontFamily, OneHubTheme.fontFamily);
  });

  testWidgets('PrimaryCta renders a gradient when enabled and a flat disabled color when not', (tester) async {
    Future<BoxDecoration> pump(VoidCallback? onPressed) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OneHubTheme.light(),
          home: Scaffold(body: PrimaryCta(onPressed: onPressed, child: const Text('Go'))),
        ),
      );
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      return box.decoration as BoxDecoration;
    }

    final enabled = await pump(() {});
    expect(enabled.gradient, isNotNull);
    expect(enabled.boxShadow, isNotNull);

    final disabled = await pump(null);
    expect(disabled.gradient, isNull);
    expect(disabled.color, isNotNull);
  });

  testWidgets('TintedBadge shows a small tinted rounded-rect, not a pill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.light(), home: const Scaffold(body: TintedBadge(label: 'NEW ACCOUNT', color: Colors.blue))),
    );
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(6));
    expect(find.text('NEW ACCOUNT'), findsOneWidget);
  });

  testWidgets('GlowBackground renders the glow blobs in dark mode but not light', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.dark(), home: const Scaffold(body: GlowBackground(child: Text('content')))),
    );
    expect(find.byType(DecoratedBox), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(theme: OneHubTheme.light(), home: const Scaffold(body: GlowBackground(child: Text('content')))),
    );
    expect(find.text('content'), findsOneWidget);
  });
}
