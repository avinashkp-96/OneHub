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
  late bool failUpload;
  // What the fake picker hands back; null is the user backing out.
  PickedPhoto? picked;

  setUp(() {
    requests = [];
    bodies = [];
    fail = false;
    failUpload = false;
    picked = PickedPhoto(Uint8List.fromList([1, 2, 3]), 'me.jpg');
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
          final path = request.url.path;
          requests.add('${request.method} $path');
          if (path.startsWith('/uploads/')) {
            if (failUpload) {
              return http.Response(jsonEncode({'message': 'too big'}), 400);
            }
            return http.Response(
                jsonEncode({
                  'url': path == '/uploads/photo'
                      ? '/api/v1/uploads/photos/new.jpg'
                      : 'upload:id-proofs/new.jpg'
                }),
                201);
          }
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
                    builder: (_) => PayoutDocumentsScreen(
                        details: d,
                        client: client,
                        pickPhoto: (_) async => picked)))),
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

  testWidgets('backing out of the picker uploads nothing', (tester) async {
    picked = null;
    await pumpScreen(tester, details());

    await tester.tap(find.byKey(const Key('change-photo')));
    await tester.tap(find.byKey(const Key('upload-id-proof')));
    await tester.pumpAndSettle();

    expect(requests, isEmpty);
    expect(find.text('Add photo'), findsOneWidget);
    expect(find.text('ON FILE'), findsOneWidget);
  });

  testWidgets('a failed upload says so and changes nothing', (tester) async {
    failUpload = true;
    await pumpScreen(tester, details());

    await tester.tap(find.byKey(const Key('change-photo')));
    await tester.pumpAndSettle();

    expect(find.text('Could not upload: too big'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
  });

  testWidgets('rejects payout details over 120 characters', (tester) async {
    await pumpScreen(tester, details());

    await tester.enterText(find.byKey(const Key('payout-field')), 'x' * 121);
    await save(tester);

    expect(find.textContaining('120 characters'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('a new photo is uploaded, then saved to /users/me only',
      (tester) async {
    final popped = await pumpScreen(tester, details());

    await tester.tap(find.byKey(const Key('change-photo')));
    await tester.pumpAndSettle();
    expect(requests, ['POST /uploads/photo']);
    expect(find.text('Change photo'), findsOneWidget);
    final preview =
        tester.widget<ProfileAvatar>(find.byKey(const Key('photo-preview')));
    expect(preview.photoUrl, 'https://example.test/api/v1/uploads/photos/new.jpg');

    await save(tester);

    expect(requests, ['POST /uploads/photo', 'PATCH /users/me']);
    expect(bodies, [
      {'profilePhotoUrl': '/api/v1/uploads/photos/new.jpg'}
    ]);
    expect(popped, [true]);
    expect(find.text('Saved.'), findsOneWidget);
  });

  testWidgets('Remove clears the photo', (tester) async {
    await pumpScreen(tester, details(photo: 'https://example.test/old.jpg'));

    await tester.tap(find.byKey(const Key('remove-photo')));
    await tester.pump();
    expect(find.text('Add photo'), findsOneWidget);
    await save(tester);

    expect(bodies, [
      {'profilePhotoUrl': null}
    ]);
  });

  testWidgets('a new ID and payout go to /providers/me together',
      (tester) async {
    final popped = await pumpScreen(tester, details());

    await tester.tap(find.byKey(const Key('upload-id-proof')));
    await tester.pumpAndSettle();
    expect(find.text('READY TO SAVE'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('payout-field')), 'rajesh@okhdfc');
    await save(tester);

    expect(requests, ['POST /uploads/id-proof', 'PATCH /providers/me']);
    expect(bodies, [
      {
        'idProofUrl': 'upload:id-proofs/new.jpg',
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
