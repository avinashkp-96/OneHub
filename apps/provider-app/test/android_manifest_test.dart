import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The installed Android app needs network access to reach the API. These
// settings live in XML that no widget test exercises, so guard them here.
void main() {
  String manifest(String variant) =>
      File('android/app/src/$variant/AndroidManifest.xml').readAsStringSync();

  test('every build may use the internet', () {
    expect(manifest('main'), contains('android.permission.INTERNET'));
  });

  test('debug builds may call a plain http dev API', () {
    expect(manifest('debug'), contains('android:usesCleartextTraffic="true"'));
  });

  test('release builds keep the plain http block', () {
    expect(manifest('main'), isNot(contains('usesCleartextTraffic')));
  });
}
