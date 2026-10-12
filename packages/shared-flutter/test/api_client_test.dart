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

  test('put sends a PUT with the bearer token', () async {
    stored['access_token'] = 'tok';
    late http.Request seen;
    final api = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );

    final result = await api
        .put('/providers/p1/subscription', {'plan': 'MONTHLY_99'}, auth: true);

    expect(seen.method, 'PUT');
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(jsonDecode(seen.body), {'plan': 'MONTHLY_99'});
    expect(result, {'ok': true});
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

  group('response bodies', () {
    ApiClient respondWith(int status, String body) => ApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((_) async => http.Response(body, status)),
        );

    test('a GET with an empty body answers null, not a FormatException',
        () async {
      // Nest sends nothing when a handler returns null, e.g. GET
      // /ratings/requirement/:id for a job that has not been rated.
      final api = respondWith(200, '');

      expect(await api.get('/ratings/requirement/r1'), isNull);
    });

    test('a GET still decodes a JSON body', () async {
      final api = respondWith(200, jsonEncode([1, 2]));

      expect(await api.get('/anything'), [1, 2]);
    });

    test('a GET error with a JSON message surfaces it', () async {
      final api = respondWith(403, jsonEncode({'message': 'not yours'}));

      expect(
        () => api.get('/anything'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', 'not yours')),
      );
    });

    test('a GET error with an HTML body is an ApiException with the status',
        () async {
      final api = respondWith(502, '<html>Bad gateway</html>');

      expect(
        () => api.get('/anything'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 502)
            .having((e) => e.message, 'message', 'request failed')),
      );
    });

    test('a POST with an empty success body returns an empty map', () async {
      final api = respondWith(200, '');

      expect(await api.post('/anything', {}), isEmpty);
    });

    test('a POST error with an empty body is an ApiException', () async {
      final api = respondWith(500, '');

      expect(
        () => api.post('/anything', {}),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('a POST error with a JSON message surfaces it', () async {
      final api = respondWith(409, jsonEncode({'message': 'already rated'}));

      expect(
        () => api.post('/ratings', {}),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'already rated')),
      );
    });
  });
}
