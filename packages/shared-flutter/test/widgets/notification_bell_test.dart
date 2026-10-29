import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  // A fake backend whose single notification starts unread and is marked read
  // by either PATCH route, so the bell can be checked before and after.
  ApiClient fakeApi({bool unread = true, bool fail = false}) {
    var isUnread = unread;
    return ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        if (fail) return http.Response(jsonEncode({'message': 'down'}), 500);
        if (request.method == 'PATCH') {
          isUnread = false;
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response(
            jsonEncode([
              {
                'id': 'n1',
                'event': 'NEW_REQUEST',
                'message': 'New job request: Switchboard Repair',
                'createdAt': DateTime.now().toUtc().toIso8601String(),
                'readAt': isUnread ? null : DateTime.now().toIso8601String(),
              }
            ]),
            200);
      }),
    );
  }

  Future<void> pumpBell(WidgetTester tester, ApiClient api) async {
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: Scaffold(body: Center(child: NotificationBell(api: api))),
    ));
    await tester.pumpAndSettle();
  }

  final dot = find.byKey(const Key('bell-unread-dot'));

  testWidgets('shows the dot while something is unread', (tester) async {
    await pumpBell(tester, fakeApi());
    expect(dot, findsOneWidget);
  });

  testWidgets('hides the dot when everything is read', (tester) async {
    await pumpBell(tester, fakeApi(unread: false));
    expect(dot, findsNothing);
  });

  testWidgets('hides the dot when the check fails', (tester) async {
    await pumpBell(tester, fakeApi(fail: true));
    expect(dot, findsNothing);
  });

  testWidgets('opens the list, and rechecks the dot on return',
      (tester) async {
    await pumpBell(tester, fakeApi());

    await tester.tap(find.byIcon(OneHubIcons.notification));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);

    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen), findsNothing);
    expect(dot, findsNothing);
  });
}
