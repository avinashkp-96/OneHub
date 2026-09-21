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

  test('primary CTAs get a full-width minimum height for outdoor tap targets', () {
    final theme = OneHubTheme.light();
    final buttonStyle = theme.filledButtonTheme.style;
    final minSize = buttonStyle?.minimumSize?.resolve({});
    expect(minSize?.height, 48);
  });
}
