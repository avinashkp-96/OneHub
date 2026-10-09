import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A tiny in-memory stand-in for the secure-storage plugin.
  final stored = <String, String>{};

  setUp(() {
    stored.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        switch (call.method) {
          case 'write':
            stored[args['key'] as String] = args['value'] as String;
            return null;
          case 'read':
            return stored[args['key']];
          case 'delete':
            stored.remove(args['key']);
            return null;
        }
        return null;
      },
    );
  });

  ApiClient client() => ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            return http.Response(jsonEncode({'accessToken': 'abc123'}), 200);
          }
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

  test('a response with an access token is remembered', () async {
    final api = client();

    await api.post('/auth/login', {});

    expect(await api.token, 'abc123');
  });

  test('logout forgets the stored token', () async {
    final api = client();
    await api.post('/auth/login', {});
    expect(await api.token, isNotNull);

    await api.logout();

    expect(await api.token, isNull);
  });

  test('logout with nobody signed in is harmless', () async {
    final api = client();

    await api.logout();

    expect(await api.token, isNull);
  });
}
