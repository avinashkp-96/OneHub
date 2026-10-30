import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/business/business_details.dart';
import 'package:onehub_provider/features/profile/payout_documents_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  late List<String> requests;
  late List<Object?> bodies;
  late bool fail;

  setUp(() {
    requests = [];
    bodies = [];
    fail = false;
    // Authenticated calls read the token from secure storage.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => 'token',
    );
  });

  ApiClient fakeClient() => ApiClient(
        baseUrl: 'https://example.test',
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          bodies.add(jsonDecode(request.body));
          return fail
              ? http.Response(jsonEncode({'message': 'nope'}), 500)
              : http.Response(jsonEncode({}), 200);
        }),
      );

  BusinessDetails details({
    String? photo,
    bool idOnFile = true,
    bool idReview = false,
    String? masked,
  }) =>
      BusinessDetails(
        categoryId: null,
        categoryName: null,
        services: const [],
        yearsExperience: null,
        coverageRadiusKm: 5,
        businessName: 'Rajesh Electricals',
        profilePhotoUrl: photo,
        idProofOnFile: idOnFile,
        idProofNeedsReview: idReview,
        bankOrUpiMasked: masked,
      );

  // Opens the screen from a stand-in page, which reports what it popped with.
  Future<List<Object?>> pumpScreen(
      WidgetTester tester, BusinessDetails d) async {
    final popped = <Object?>[];
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = fakeClient();
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => popped.add(await Navigator.of(context)
                .push<bool>(MaterialPageRoute(
                    builder: (_) =>
                        PayoutDocumentsScreen(details: d, client: client)))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return popped;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the shell, the ID status and the masked payout',
      (tester) async {
    await pumpScreen(tester, details(masked: 'ra••••@okhdfc'));

    expect(find.text('Payout & documents'), findsOneWidget);
    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('ON FILE'), findsOneWidget);
    expect(find.text('On file: ra••••@okhdfc'), findsOneWidget);
    expect(find.text('Leave empty to keep ra••••@okhdfc.'), findsOneWidget);
    expect(find.text('Remove my payout details'), findsOneWidget);
  });

  testWidgets('labels an ID under review and a missing one', (tester) async {
    await pumpScreen(tester, details(idReview: true));
    expect(find.text('UNDER REVIEW'), findsOneWidget);
    expect(find.text('No payout details yet.'), findsOneWidget);
    expect(find.text('Remove my payout details'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester, details(idOnFile: false));
    expect(find.text('NOT ADDED'), findsOneWidget);
  });

  testWidgets('saving with nothing changed sends nothing', (tester) async {
    await pumpScreen(tester, details());

    await save(tester);

    expect(find.text('Nothing to save yet.'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('rejects links that are not http or https', (tester) async {
    await pumpScreen(tester, details());

    await tester.enterText(find.byKey(const Key('photo-field')), 'me.jpg');
    await save(tester);
    expect(find.textContaining('photo link must start'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('photo-field')), '');
    await tester.enterText(find.byKey(const Key('id-proof-field')), 'id');
    await save(tester);
    expect(find.textContaining('ID proof link must start'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('rejects payout details over 120 characters', (tester) async {
    await pumpScreen(tester, details());

    await tester.enterText(find.byKey(const Key('payout-field')), 'x' * 121);
    await save(tester);

    expect(find.textContaining('120 characters'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('a new photo link goes to /users/me only', (tester) async {
    final popped = await pumpScreen(tester, details());

    await tester.enterText(
        find.byKey(const Key('photo-field')), ' https://example.test/me.jpg ');
    await save(tester);

    expect(requests, ['PATCH /users/me']);
    expect(bodies, [
      {'profilePhotoUrl': 'https://example.test/me.jpg'}
    ]);
    expect(popped, [true]);
    expect(find.text('Saved.'), findsOneWidget);
  });

  testWidgets('emptying the photo link clears it', (tester) async {
    await pumpScreen(tester, details(photo: 'https://example.test/old.jpg'));

    await tester.enterText(find.byKey(const Key('photo-field')), '');
    await save(tester);

    expect(bodies, [
      {'profilePhotoUrl': null}
    ]);
  });

  testWidgets('a new ID and payout go to /providers/me together',
      (tester) async {
    final popped = await pumpScreen(tester, details());

    await tester.enterText(
        find.byKey(const Key('id-proof-field')), 'https://example.test/id.pdf');
    await tester.enterText(
        find.byKey(const Key('payout-field')), 'rajesh@okhdfc');
    await save(tester);

    expect(requests, ['PATCH /providers/me']);
    expect(bodies, [
      {
        'idProofUrl': 'https://example.test/id.pdf',
        'bankOrUpiDetails': 'rajesh@okhdfc'
      }
    ]);
    expect(popped, [true]);
    expect(find.text('Saved. Your new ID is under review.'), findsOneWidget);
  });

  testWidgets('Remove my payout details sends an empty value', (tester) async {
    await pumpScreen(tester, details(masked: 'ra••••@okhdfc'));

    await tester.enterText(find.byKey(const Key('payout-field')), 'typed');
    await tester.tap(find.text('Remove my payout details'));
    await tester.pump();
    final field =
        tester.widget<TextField>(find.byKey(const Key('payout-field')));
    expect(field.enabled, isFalse);
    expect(field.controller!.text, isEmpty);

    await save(tester);

    expect(bodies, [
      {'bankOrUpiDetails': ''}
    ]);
  });

  testWidgets('a failed save stays open with the error', (tester) async {
    fail = true;
    final popped = await pumpScreen(tester, details());

    await tester.enterText(
        find.byKey(const Key('payout-field')), 'rajesh@okhdfc');
    await save(tester);

    expect(find.byType(PayoutDocumentsScreen), findsOneWidget);
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(popped, isEmpty);
    final cta = tester.widget<PrimaryCta>(find.byType(PrimaryCta));
    expect(cta.onPressed, isNotNull, reason: 'you can try again');
  });

  testWidgets('the back button leaves without saving', (tester) async {
    final popped = await pumpScreen(tester, details());

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(PayoutDocumentsScreen), findsNothing);
    expect(popped, [null]);
    expect(requests, isEmpty);
  });
}
