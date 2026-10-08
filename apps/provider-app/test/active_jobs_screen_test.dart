import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/requirements/active_jobs_screen.dart';
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

  late List<String> calls;

  Map<String, dynamic> bid({required bool confirmed}) => {
        'id': 'b1',
        'providerId': 'p1',
        'initialMinPrice': 500,
        'initialMaxPrice': 900,
        'contactUnlocked': true,
        'confirmed': confirmed,
      };

  Map<String, dynamic> job(String id, String description, String status,
          {List<Map<String, dynamic>>? bids}) =>
      {
        'id': id,
        'subServiceId': 's1',
        'description': description,
        'photoUrls': [],
        'status': status,
        'bids': bids ?? [],
      };

  ApiClient fakeClient(
      {List<Map<String, dynamic>>? jobs, bool failComplete = false}) {
    calls = [];
    final items = jobs ??
        [
          job('j1', 'Awaiting job', 'BID_RECEIVED',
              bids: [bid(confirmed: false)]),
          job('j2', 'Selected job', 'CONFIRMED', bids: [bid(confirmed: true)]),
          job('j3', 'Lost job', 'CONFIRMED', bids: [bid(confirmed: false)]),
          job('j4', 'Done job', 'COMPLETED', bids: [bid(confirmed: true)]),
          job('j5', 'Not bid on yet', 'SENT'),
        ];
    return ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.url.path == '/requirements/incoming') {
          return http.Response(jsonEncode(items), 200);
        }
        if (request.url.path.endsWith('/complete') && failComplete) {
          return http.Response(jsonEncode({'message': 'Not allowed'}), 403);
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );
  }

  Future<void> pumpScreen(WidgetTester tester, ApiClient client) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
          theme: OneHubTheme.dark(), home: ActiveJobsScreen(client: client)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'shows a status badge per job and hides requests the provider has not bid on',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsNothing);
    expect(find.text('Active jobs'), findsOneWidget);
    expect(find.text('AWAITING SELECTION'), findsOneWidget);
    expect(find.text('SELECTED'), findsOneWidget);
    expect(find.text('NOT SELECTED'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('Not bid on yet'), findsNothing);
  });

  testWidgets('only a selected job offers Mark as Completed', (tester) async {
    await pumpScreen(tester, fakeClient());

    expect(
        find.widgetWithText(PrimaryCta, 'Mark as Completed'), findsOneWidget);
    expect(
        find.text('You were picked. Go ahead with the job.'), findsOneWidget);
  });

  testWidgets('marking a job completed calls the API and reloads',
      (tester) async {
    await pumpScreen(tester, fakeClient());

    await tester.tap(find.widgetWithText(PrimaryCta, 'Mark as Completed'));
    await tester.pumpAndSettle();

    expect(calls, contains('PATCH /requirements/j2/complete'));
    expect(calls.where((c) => c == 'GET /requirements/incoming').length, 2);
  });

  testWidgets('shows an error when marking complete fails', (tester) async {
    await pumpScreen(tester, fakeClient(failComplete: true));

    await tester.tap(find.widgetWithText(PrimaryCta, 'Mark as Completed'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not mark this job complete'),
        findsOneWidget);
  });

  testWidgets('shows an empty state when there are no active jobs',
      (tester) async {
    await pumpScreen(
        tester, fakeClient(jobs: [job('j5', 'Not bid on yet', 'SENT')]));

    expect(find.text('No active jobs right now.'), findsOneWidget);
  });

  testWidgets('shows an error when the jobs cannot be loaded', (tester) async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async =>
          http.Response(jsonEncode({'message': 'Server down'}), 500)),
    );
    await pumpScreen(tester, client);

    expect(find.textContaining('Could not load active jobs'), findsOneWidget);
  });
}
