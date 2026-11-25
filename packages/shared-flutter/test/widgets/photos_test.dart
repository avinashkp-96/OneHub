import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final stored = <String, String>{};
  setUp(() {
    stored
      ..clear()
      ..['access_token'] = 'tok';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        return switch (call.method) {
          'read' => stored[args['key']],
          'write' => stored[args['key'] as String] = args['value'] as String,
          'delete' => stored.remove(args['key']),
          _ => null,
        };
      },
    );
  });

  group('ApiClient.upload', () {
    late List<http.BaseRequest> seen;

    ApiClient answering(int status, Object body) {
      seen = [];
      return ApiClient(
        baseUrl: 'https://example.test/api/v1',
        httpClient: MockClient((request) async {
          seen.add(request);
          return http.Response(jsonEncode(body), status);
        }),
      );
    }

    test('sends the bytes as multipart "file" with the token, returns the url',
        () async {
      final api = answering(201, {'url': '/api/v1/uploads/photos/a.jpg'});

      final url = await api.upload('/uploads/photo', [1, 2, 3], 'fan.jpg');

      expect(url, '/api/v1/uploads/photos/a.jpg');
      final request = seen.single as http.Request;
      expect(request.method, 'POST');
      expect(request.url.toString(),
          'https://example.test/api/v1/uploads/photo');
      expect(request.headers['Authorization'], 'Bearer tok');
      expect(request.headers['content-type'], startsWith('multipart/form-data'));
      final body = latin1.decode(request.bodyBytes);
      expect(body, contains('name="file"; filename="fan.jpg"'));
    });

    test('an upload during signup sends no token', () async {
      final api = answering(201, {'url': 'upload:id-proofs/a.jpg'});

      await api.upload('/uploads/id-proof', [1], 'id.jpg', auth: false);

      expect(seen.single.headers.containsKey('Authorization'), isFalse);
    });

    test('a too-large file reads as a plain message', () async {
      final api = answering(413, {'message': 'File too large'});

      expect(
          () => api.upload('/uploads/photo', [1], 'big.jpg'),
          throwsA(isA<ApiException>()
              .having((e) => e.message, 'message', 'image must be 5 MB or smaller')));
    });

    test("other refusals carry the API's message", () async {
      final api = answering(
          400, {'message': 'only JPEG, PNG or WebP images can be uploaded'});

      expect(
          () => api.upload('/uploads/photo', [1], 'a.gif'),
          throwsA(isA<ApiException>().having((e) => e.message, 'message',
              'only JPEG, PNG or WebP images can be uploaded')));
    });

    test('an expired token is renewed and the upload sent again', () async {
      stored['refresh_token'] = 'r1';
      final paths = <String>[];
      final api = ApiClient(
        baseUrl: 'https://example.test/api/v1',
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/auth/refresh')) {
            return http.Response(
                jsonEncode({'accessToken': 'new', 'refreshToken': 'r2'}), 200);
          }
          if (request.headers['Authorization'] == 'Bearer new') {
            return http.Response(jsonEncode({'url': '/u/x.jpg'}), 201);
          }
          return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
        }),
      );

      expect(await api.upload('/uploads/photo', [1], 'a.jpg'), '/u/x.jpg');
      expect(paths, [
        '/api/v1/uploads/photo',
        '/api/v1/auth/refresh',
        '/api/v1/uploads/photo'
      ]);
    });
  });

  group('ApiClient.resolve', () {
    test('puts a stored path on the API host for an installed app', () {
      final api = ApiClient(baseUrl: 'https://192.168.1.5:8443/api/v1');
      expect(api.resolve('/api/v1/uploads/photos/a.jpg'),
          'https://192.168.1.5:8443/api/v1/uploads/photos/a.jpg');
    });

    test('leaves a path alone for the web build, and full links always', () {
      expect(ApiClient(baseUrl: '/api/v1').resolve('/api/v1/uploads/photos/a.jpg'),
          '/api/v1/uploads/photos/a.jpg');
      expect(ApiClient(baseUrl: 'https://x.test/api/v1').resolve('https://cdn.test/a.jpg'),
          'https://cdn.test/a.jpg');
    });
  });

  Widget app(Widget child) =>
      MaterialApp(theme: OneHubTheme.dark(), home: Scaffold(body: child));

  group('PhotoStrip and PhotoViewer', () {
    testWidgets('shows a thumbnail per photo and opens the viewer at the tapped one',
        (tester) async {
      await tester.pumpWidget(app(const PhotoStrip(urls: ['a.jpg', 'b.jpg', 'c.jpg'])));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoThumb), findsNWidgets(3));
      expect(find.byIcon(OneHubIcons.image), findsNWidgets(3),
          reason: 'a photo that cannot load shows an icon, not an error');

      await tester.tap(find.byKey(const Key('photo-1')));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-600, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('3 of 3'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsNothing);
    });
  });

  group('ProfileAvatar', () {
    testWidgets('shows the initial without a photo, and no badge without onTap',
        (tester) async {
      await tester.pumpWidget(app(const ProfileAvatar(name: ' meera')));

      expect(find.text('M'), findsOneWidget);
      expect(find.byIcon(OneHubIcons.camera), findsNothing);
    });

    testWidgets('shows the photo instead of the initial', (tester) async {
      await tester.pumpWidget(
          app(const ProfileAvatar(name: 'Meera', photoUrl: 'https://x.test/m.jpg')));
      await tester.pump();

      expect(find.text('M'), findsNothing);
    });

    testWidgets('with onTap: a camera badge, a tap, and a spinner while busy',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(app(ProfileAvatar(name: '', onTap: () => taps++)));

      expect(find.text('?'), findsOneWidget);
      expect(find.byIcon(OneHubIcons.camera), findsOneWidget);
      await tester.tap(find.byType(ProfileAvatar));
      expect(taps, 1);

      await tester.pumpWidget(
          app(ProfileAvatar(name: 'A', busy: true, onTap: () => taps++)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(ProfileAvatar));
      expect(taps, 1, reason: 'no second pick while one is saving');
    });
  });

  testWidgets('choosePhoto offers camera and gallery, and backing out gives null',
      (tester) async {
    PickedPhoto? result = PickedPhoto(Uint8List(0), 'x');
    var done = false;
    await tester.pumpWidget(app(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          result = await choosePhoto(context);
          done = true;
        },
        child: const Text('pick'),
      ),
    )));

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(result, isNull);
  });

  testWidgets('RequestDetailScreen shows photos only when there are some',
      (tester) async {
    RequestDetailScreen detail(List<String> photos) => RequestDetailScreen(
          heading: 'Request',
          description: 'Fan',
          statusLabel: 'SENT',
          statusColor: Colors.blue,
          steps: const [],
          photos: photos,
        );

    await tester.pumpWidget(MaterialApp(home: detail(const [])));
    expect(find.text('Photos'), findsNothing);

    await tester.pumpWidget(MaterialApp(home: detail(const ['a.jpg', 'b.jpg'])));
    await tester.pumpAndSettle();
    expect(find.text('Photos'), findsOneWidget);
    expect(find.byType(PhotoThumb), findsNWidgets(2));
  });
}
