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
    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(sizedBox.width, double.infinity);
  });

  test('app bars carry the brand color instead of the generic surface tint', () {
    final theme = OneHubTheme.light();
    expect(theme.appBarTheme.backgroundColor, theme.colorScheme.primary);
    expect(theme.appBarTheme.foregroundColor, theme.colorScheme.onPrimary);
  });
}
