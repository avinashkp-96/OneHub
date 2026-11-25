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

  group('expired session', () {
    // Answers 401 to everything but login, which hands out a fresh token.
    ApiClient expiring(void Function() onExpired) => ApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((request) async {
            if (request.url.path == '/auth/login') {
              return http.Response(jsonEncode({'accessToken': 'new'}), 200);
            }
            return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
          }),
        )..onSessionExpired = onExpired;

    test('a 401 on a signed-in call forgets the token and reports it once',
        () async {
      stored['access_token'] = 'old';
      var reports = 0;
      final api = expiring(() => reports++);

      await expectLater(api.get('/requirements/incoming'),
          throwsA(isA<ApiException>()));
      await expectLater(api.get('/providers/me'), throwsA(isA<ApiException>()));
      await expectLater(api.patch('/users/me', {}, auth: true),
          throwsA(isA<ApiException>()));

      expect(reports, 1);
      expect(await api.token, isNull);
    });

    test('reports again after the next login', () async {
      stored['access_token'] = 'old';
      var reports = 0;
      final api = expiring(() => reports++);

      await expectLater(api.get('/a'), throwsA(isA<ApiException>()));
      await api.post('/auth/login', {});
      await expectLater(api.get('/b'), throwsA(isA<ApiException>()));

      expect(reports, 2);
    });

    test('a 401 from a call made without auth, such as a wrong password, '
        'is not an expired session', () async {
      stored['access_token'] = 'old';
      var reports = 0;
      final api = ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((_) async =>
            http.Response(jsonEncode({'message': 'invalid credentials'}), 401)),
      )..onSessionExpired = () => reports++;

      await expectLater(
          api.post('/auth/customer/login', {}), throwsA(isA<ApiException>()));

      expect(reports, 0);
      expect(await api.token, 'old');
    });

    test('other errors leave the session alone', () async {
      stored['access_token'] = 'old';
      var reports = 0;
      final api = ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((_) async =>
            http.Response(jsonEncode({'message': 'not yours'}), 403)),
      )..onSessionExpired = () => reports++;

      await expectLater(api.get('/x'), throwsA(isA<ApiException>()));

      expect(reports, 0);
      expect(await api.token, 'old');
    });
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

  group('staying signed in', () {
    // A fake API whose access token "old" has expired and "new" works.
    // /auth/refresh answers with [refreshStatus] (or throws when null is
    // given for [reachable]); every request is recorded in [log].
    late List<String> log;
    late List<String?> bearers;
    late List<Map<String, dynamic>> refreshBodies;

    ApiClient signedIn(
        {int refreshStatus = 200,
        bool reachable = true,
        bool newTokenWorks = true}) {
      log = [];
      bearers = [];
      refreshBodies = [];
      return ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          final path = request.url.path;
          log.add('${request.method} $path');
          if (path == '/auth/refresh') {
            if (!reachable) throw http.ClientException('offline');
            refreshBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            if (refreshStatus != 200) {
              return http.Response(
                  jsonEncode({'message': 'sign-in expired'}), refreshStatus);
            }
            return http.Response(
                jsonEncode({'accessToken': 'new', 'refreshToken': 'r2'}), 200);
          }
          if (path == '/auth/logout') {
            if (!reachable) throw http.ClientException('offline');
            refreshBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(jsonEncode({'loggedOut': true}), 200);
          }
          if (path == '/auth/login') {
            return http.Response(
                jsonEncode({'accessToken': 'old', 'refreshToken': 'r1'}), 200);
          }
          final bearer = request.headers['Authorization'];
          bearers.add(bearer);
          if (bearer == 'Bearer new' && newTokenWorks) {
            return http.Response(jsonEncode({'ok': path}), 200);
          }
          return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
        }),
      );
    }

    setUp(() {
      stored['access_token'] = 'old';
      stored['refresh_token'] = 'r1';
    });

    test('login stores the refresh token as well', () async {
      stored.clear();
      final api = signedIn();

      await api.post('/auth/login', {});

      expect(stored, {'access_token': 'old', 'refresh_token': 'r1'});
    });

    test('an expired access token is renewed and the call sent again',
        () async {
      var expired = 0;
      final api = signedIn()..onSessionExpired = () => expired++;

      expect(await api.get('/providers/me'), {'ok': '/providers/me'});

      expect(log, ['GET /providers/me', 'POST /auth/refresh', 'GET /providers/me']);
      expect(refreshBodies.single, {'refreshToken': 'r1'});
      expect(bearers, ['Bearer old', 'Bearer new']);
      expect(stored, {'access_token': 'new', 'refresh_token': 'r2'});
      expect(expired, 0);
    });

    test('a signed-in POST renews too', () async {
      final api = signedIn();

      expect(await api.patch('/users/me', {'fullName': 'A'}, auth: true),
          {'ok': '/users/me'});
      expect(log.where((l) => l == 'POST /auth/refresh'), hasLength(1));
    });

    test('calls that fail together share one renewal', () async {
      final api = signedIn();

      final results = await Future.wait(
          [api.get('/a'), api.get('/b'), api.get('/c')]);

      expect(results, [
        {'ok': '/a'},
        {'ok': '/b'},
        {'ok': '/c'}
      ]);
      expect(log.where((l) => l == 'POST /auth/refresh'), hasLength(1));
    });

    test('a refused refresh ends the sign-in once and forgets both tokens',
        () async {
      var expired = 0;
      final api = signedIn(refreshStatus: 401)..onSessionExpired = () => expired++;

      await expectLater(api.get('/a'), throwsA(isA<ApiException>()));
      await expectLater(api.get('/b'), throwsA(isA<ApiException>()));

      expect(expired, 1);
      expect(stored, isEmpty);
    });

    test('an unreachable API keeps the sign-in', () async {
      var expired = 0;
      final api = signedIn(reachable: false)..onSessionExpired = () => expired++;

      await expectLater(
          api.get('/a'),
          throwsA(isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)));

      expect(expired, 0);
      expect(stored, {'access_token': 'old', 'refresh_token': 'r1'});
    });

    test('a server error while renewing keeps the sign-in', () async {
      var expired = 0;
      final api = signedIn(refreshStatus: 503)..onSessionExpired = () => expired++;

      await expectLater(api.get('/a'), throwsA(isA<ApiException>()));

      expect(expired, 0);
      expect(stored['refresh_token'], 'r1');
    });

    test('a call still refused after renewing ends the sign-in', () async {
      var expired = 0;
      final api = signedIn(newTokenWorks: false)
        ..onSessionExpired = () => expired++;

      await expectLater(api.get('/a'), throwsA(isA<ApiException>()));

      expect(expired, 1);
      expect(stored, isEmpty);
    });

    test('logout revokes the refresh token on the API and forgets both',
        () async {
      final api = signedIn();

      await api.logout();

      expect(log, ['POST /auth/logout']);
      expect(refreshBodies.single, {'refreshToken': 'r1'});
      expect(stored, isEmpty);
    });

    test('logout offline still signs out on this device', () async {
      final api = signedIn(reachable: false);

      await api.logout();

      expect(stored, isEmpty);
    });
  });
}
