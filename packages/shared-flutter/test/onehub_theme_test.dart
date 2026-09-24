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
    expect(dark.scaffoldBackgroundColor,
        isNot(equals(light.scaffoldBackgroundColor)));
  });

  test('dark scaffold background matches the style guide PDF exactly', () {
    expect(OneHubColors.surfaceDark, const Color(0xFF111318));
  });

  test(
      'buttons get a 48px minimum height for outdoor tap targets, not forced full width',
      () {
    final theme = OneHubTheme.light();
    final buttonStyle = theme.filledButtonTheme.style;
    final minSize = buttonStyle?.minimumSize?.resolve({});
    expect(minSize?.height, 48);
    expect(minSize?.width, isNot(double.infinity));
  });

  testWidgets('PrimaryCta stretches to the width its parent allows',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.light(),
        home: const Scaffold(
          body: SizedBox(
              width: 300,
              child: PrimaryCta(onPressed: null, child: Text('Go'))),
        ),
      ),
    );
    // find.byType(SizedBox).first would find the test's own 300px wrapper
    // (higher in the tree) instead of PrimaryCta's internal one — be explicit
    // about which SizedBox this assertion is actually about.
    final innerSizedBox = tester.widget<SizedBox>(
      find.descendant(
          of: find.byType(PrimaryCta), matching: find.byType(SizedBox)),
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
    final shape = theme.filledButtonTheme.style?.shape?.resolve({})
        as RoundedRectangleBorder?;
    expect(shape?.borderRadius, BorderRadius.circular(14));
  });

  test(
      'cards have a visible border and the style guide\'s 20px "Form card" radius',
      () {
    final theme = OneHubTheme.dark();
    final shape = theme.cardTheme.shape as RoundedRectangleBorder?;
    expect(shape?.side.color, OneHubColors.cardBorderDark);
    expect(shape?.side, isNot(BorderSide.none));
    expect(shape?.borderRadius, BorderRadius.circular(20));
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

  testWidgets(
      'PrimaryCta renders a gradient when enabled and a flat disabled color when not',
      (tester) async {
    Future<BoxDecoration> pump(VoidCallback? onPressed) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OneHubTheme.light(),
          home: Scaffold(
              body: PrimaryCta(onPressed: onPressed, child: const Text('Go'))),
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

  testWidgets(
      'TintedBadge defaults to the style guide\'s 6px "GPS badge" radius',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
          theme: OneHubTheme.light(),
          home: const Scaffold(
              body: TintedBadge(label: 'GPS', color: Colors.blue))),
    );
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(6));
    expect(find.text('GPS'), findsOneWidget);
  });

  testWidgets(
      'TintedBadge(pill: true) uses the style guide\'s 99px "Pill badges" radius',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
          theme: OneHubTheme.light(),
          home: const Scaffold(
              body: TintedBadge(
                  label: 'NEW ACCOUNT', color: Colors.blue, pill: true))),
    );
    final container = tester.widget<Container>(find.byType(Container));
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(99));
  });

  test('OneHubTextStyles matches the style guide\'s 7-entry type scale exactly',
      () {
    expect(OneHubTextStyles.pageHeading(Colors.white).fontSize, 36);
    expect(
        OneHubTextStyles.pageHeading(Colors.white).fontWeight, FontWeight.w800);
    expect(OneHubTextStyles.buttonLabel(Colors.white).fontSize, 15);
    expect(
        OneHubTextStyles.buttonLabel(Colors.white).fontWeight, FontWeight.w700);
    expect(OneHubTextStyles.linkText(Colors.white).fontSize, 13);
    expect(OneHubTextStyles.linkText(Colors.white).fontWeight, FontWeight.w600);
    expect(OneHubTextStyles.bodyText(Colors.white).fontSize, 14);
    expect(OneHubTextStyles.bodyText(Colors.white).fontWeight, FontWeight.w400);
    expect(OneHubTextStyles.badgeLabel(Colors.white).fontSize, 11);
    expect(
        OneHubTextStyles.badgeLabel(Colors.white).fontWeight, FontWeight.w700);
    expect(OneHubTextStyles.fieldLabel(Colors.white).fontSize, 10.5);
    expect(
        OneHubTextStyles.fieldLabel(Colors.white).fontWeight, FontWeight.w600);
  });

  test(
      'input text (TextField default style) is Medium/14px per the style guide',
      () {
    final textTheme = OneHubTheme.dark().textTheme;
    expect(textTheme.titleMedium?.fontSize, 14);
    expect(textTheme.titleMedium?.fontWeight, FontWeight.w500);
  });

  test('exact color tokens from the style guide PDF', () {
    expect(OneHubColors.accentPurple, const Color(0xFFB39CFF));
    expect(OneHubColors.requiredAsterisk, const Color(0xFFFF6B6B));
    expect(OneHubColors.textPrimaryDark, const Color(0xEBFFFFFF));
    expect(OneHubColors.textSecondaryDark, const Color(0x8CFFFFFF));
    expect(OneHubColors.textMutedDark, const Color(0x59FFFFFF));
  });

  testWidgets(
      'GlowCard renders a bottom-left blue glow and a top-right light glow, both clipped to the card',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
          theme: OneHubTheme.dark(),
          home: const Scaffold(body: GlowCard(child: Text('content')))),
    );
    expect(find.byType(ClipRRect), findsOneWidget);
    expect(find.text('content'), findsOneWidget);

    final gradients = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => (box.decoration as BoxDecoration).gradient)
        .whereType<RadialGradient>()
        .toList();
    expect(gradients.map((g) => g.colors.first),
        containsAll([OneHubColors.glowBlue1, OneHubColors.glowLight]));
    expect(
        gradients
            .firstWhere((g) => g.colors.first == OneHubColors.glowBlue1)
            .center,
        Alignment.bottomLeft);
    expect(
        gradients
            .firstWhere((g) => g.colors.first == OneHubColors.glowLight)
            .center,
        Alignment.topRight);

    await tester.pumpWidget(
      MaterialApp(
          theme: OneHubTheme.light(),
          home: const Scaffold(body: GlowCard(child: Text('content')))),
    );
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets(
      'PrimaryCta uses the exact brand gradient and white label, not a seed-derived color',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
          theme: OneHubTheme.light(),
          home: const Scaffold(
              body: PrimaryCta(onPressed: null, child: Text('Go')))),
    );
    // Rebuild enabled so we can inspect the gradient/text colors.
    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.light(),
        home: Scaffold(
            body: PrimaryCta(onPressed: () {}, child: const Text('Go'))),
      ),
    );
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = box.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    expect(gradient.colors,
        [OneHubColors.primary, OneHubColors.primaryGradientEnd]);
    expect(gradient.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);

    final label = tester.widget<Text>(find.text('Go'));
    final defaultStyle = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
              of: find.text('Go'), matching: find.byType(DefaultTextStyle))
          .first,
    );
    expect((label.style ?? defaultStyle.style).color, Colors.white);
  });
}
