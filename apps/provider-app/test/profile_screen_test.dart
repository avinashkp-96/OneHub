import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehub_provider/features/profile/payout_documents_screen.dart';
import 'package:onehub_provider/features/profile/profile_screen.dart';
import 'package:onehub_provider/features/requirements/active_jobs_screen.dart';
import 'package:onehub_provider/features/profile/profile_state.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> storageCalls;
  late Object business;
  late List<String> requests;
  late List<Map<String, dynamic>> bodies;
  late int failPatches;

  setUp(() {
    requests = [];
    bodies = [];
    failPatches = 0;
    business = <String, dynamic>{
      'id': 'p1',
      'businessName': 'Rajesh Electricals',
      'mobile': '9000000002',
      'email': 'rajesh@example.com',
      'profilePhotoUrl': null,
      'status': 'ACTIVE',
      'idProofOnFile': true,
      'idProofNeedsReview': false,
      'bankOrUpiMasked': null,
      'yearsExperience': 8,
      'coverageRadiusKm': 10,
      'category': {'id': 'c1', 'name': 'Electrician'},
      'subServices': [
        {'id': 's1', 'name': 'Fan Installation'},
        {'id': 's2', 'name': 'Light Fitting'},
      ],
    };
  });

  // A PATCH changes what the next GET /providers/me returns, as the API does.
  void applyPatch(Map<String, dynamic> body) {
    final b = business as Map<String, dynamic>;
    for (final key in ['businessName', 'email', 'profilePhotoUrl']) {
      if (body.containsKey(key)) b[key] = body[key];
    }
    if (body.containsKey('idProofUrl')) {
      b['idProofOnFile'] = true;
      b['idProofNeedsReview'] = true;
    }
    if (body.containsKey('bankOrUpiDetails')) {
      b['bankOrUpiMasked'] =
          (body['bankOrUpiDetails'] as String).isEmpty ? null : 'ra••••@okhdfc';
    }
  }

  // Opens Profile on top of a stand-in home screen so that logging out has a
  // stack to clear, and records what the secure-storage plugin is asked to do.
  Future<void> pumpScreen(WidgetTester tester) async {
    storageCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        storageCalls.add('${call.method} ${(call.arguments as Map)['key']}');
        return null;
      },
    );
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        final path = request.url.path;
        requests.add('${request.method} $path');
        if (request.method == 'PATCH') {
          if (failPatches > 0) {
            failPatches--;
            return http.Response(jsonEncode({'message': 'nope'}), 500);
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          bodies.add(body);
          applyPatch(body);
          return http.Response(jsonEncode({}), 200);
        }
        if (path == '/providers/me') {
          return http.Response.bytes(utf8.encode(jsonEncode(business)), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response(jsonEncode([]), 200);
      }),
    );
    tester.view.physicalSize = const Size(800, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        routes: {'/login': (_) => const Scaffold(body: Text('login stub'))},
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => ProfileScreen(client: client)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the account from the API in a single GlowCard',
      (tester) async {
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Rajesh Electricals'), findsOneWidget);
    expect(find.text('+91 90000 00002'), findsOneWidget);
    expect(find.text('rajesh@example.com'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('R'), findsOneWidget,
        reason: 'the avatar shows the initial');
  });

  testWidgets('a provider with a new ID waiting shows ID UNDER REVIEW',
      (tester) async {
    (business as Map)['idProofNeedsReview'] = true;
    await pumpScreen(tester);

    expect(find.text('ID UNDER REVIEW'), findsOneWidget);
    expect(find.text('VERIFIED'), findsNothing);
  });

  testWidgets('a provider not yet active shows PENDING and no email row',
      (tester) async {
    (business as Map)
      ..['status'] = 'PENDING_VERIFICATION'
      ..['email'] = null;
    await pumpScreen(tester);

    expect(find.text('PENDING'), findsOneWidget);
    expect(find.byIcon(OneHubIcons.email), findsNothing);
  });

  testWidgets('a photo link replaces the initial in the avatar',
      (tester) async {
    (business as Map)['profilePhotoUrl'] = 'https://example.test/me.jpg';
    await pumpScreen(tester);

    final avatar =
        tester.widget<Container>(find.byKey(const Key('profile-avatar')));
    final decoration = avatar.decoration as BoxDecoration;
    expect((decoration.image!.image as NetworkImage).url,
        'https://example.test/me.jpg');
    expect(find.text('R'), findsNothing);
  });

  testWidgets('lists the business details from the API', (tester) async {
    await pumpScreen(tester);

    expect(find.text('SERVICE CATEGORY'), findsOneWidget);
    expect(find.text('Electrician'), findsOneWidget);
    expect(find.text('SERVICES'), findsOneWidget);
    expect(find.text('2 services'), findsOneWidget);
    expect(find.text('COVERAGE'), findsOneWidget);
    expect(find.text('10 km radius'), findsOneWidget);
    expect(find.text('EXPERIENCE'), findsOneWidget);
    expect(find.text('8 years'), findsOneWidget);
    expect(requests.where((r) => r == 'GET /providers/me'), hasLength(1),
        reason: 'one fetch feeds both cards');
  });

  testWidgets('shows "Not set" for a provider with no services or experience',
      (tester) async {
    business = {'id': 'p1', 'coverageRadiusKm': 7.5, 'subServices': []};
    await pumpScreen(tester);

    expect(find.text('Not set'), findsNWidgets(2));
    expect(find.text('0 services'), findsOneWidget);
    expect(find.text('7.5 km radius'), findsOneWidget);
    expect(find.text('Provider'), findsOneWidget,
        reason: 'no business name falls back to a generic one');
  });

  testWidgets('says so when the profile cannot load, and the edits are off',
      (tester) async {
    business = ['not', 'a', 'map'];
    await pumpScreen(tester);

    expect(find.text('Could not load your business details.'), findsOneWidget);
    expect(find.textContaining('Could not load your profile'), findsOneWidget);
    final edit = tester.widget<TextButton>(find.ancestor(
        of: find.text('Edit'), matching: find.byType(TextButton)));
    expect(edit.onPressed, isNull);

    await tester.tap(find.text('Edit profile'));
    await tester.tap(find.text('Payout & documents'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.byType(PayoutDocumentsScreen), findsNothing);
  });

  testWidgets('pulling down loads the profile again', (tester) async {
    await pumpScreen(tester);
    (business as Map)['businessName'] = 'Renamed Elsewhere';

    // The indicator arms after a quarter of the (tall) viewport.
    await tester.drag(find.byType(ListView), const Offset(0, 1500));
    await tester.pumpAndSettle();

    expect(find.text('Renamed Elsewhere'), findsOneWidget);
  });

  testWidgets('Active jobs opens the jobs screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Active jobs'));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveJobsScreen), findsOneWidget);
  });

  testWidgets('the back button returns to the previous screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('Log out asks for confirmation first', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    expect(storageCalls.where((c) => c.startsWith('delete')), isEmpty);
  });

  testWidgets('cancelling leaves you on the profile screen', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Log out?'), findsNothing);
    expect(storageCalls.where((c) => c.startsWith('delete')), isEmpty);
  });

  testWidgets(
      'confirming clears the token and lands on login with nothing to go back to',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(storageCalls, contains('delete access_token'));
    expect(find.text('login stub'), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.text('open'), findsNothing,
        reason: 'the whole stack was cleared');
  });

  testWidgets('Edit profile saves name and email through the API',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('Saved on this device only for now.'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextField, 'Rajesh Electricals'), 'New Name');
    await tester.enterText(
        find.widgetWithText(TextField, 'rajesh@example.com'), '');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(requests, containsAll(['PATCH /providers/me', 'PATCH /users/me']));
    expect(bodies, [
      {'businessName': 'New Name'},
      {'email': null},
    ]);
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('New Name'), findsOneWidget);
    expect(find.text('rajesh@example.com'), findsNothing);
    expect(find.text('Profile updated.'), findsOneWidget);
  });

  testWidgets('Edit profile sends nothing for unchanged values',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'rajesh@example.com'), 'r@example.com');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(bodies, [
      {'email': 'r@example.com'},
    ]);
    expect(find.text('r@example.com'), findsOneWidget);
  });

  testWidgets('a failed save keeps Edit profile open with the error',
      (tester) async {
    failPatches = 1;
    await pumpScreen(tester);

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Rajesh Electricals'), 'New Name');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.textContaining('Could not save your profile'), findsOneWidget);
  });

  testWidgets('Payout & documents opens and a save reloads the profile',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Payout & documents'));
    await tester.pumpAndSettle();
    expect(find.byType(PayoutDocumentsScreen), findsOneWidget);

    await tester.enterText(find.byKey(const Key('id-proof-field')),
        'https://example.test/new-id.pdf');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(PayoutDocumentsScreen), findsNothing);
    expect(find.text('ID UNDER REVIEW'), findsOneWidget);
    expect(find.text('Saved. Your new ID is under review.'), findsOneWidget);
  });

  testWidgets('Settings opens with this app\'s toggles and remembers a change',
      (tester) async {
    final toggle = providerSettingsToggles.first.value;
    final before = toggle.value;
    addTearDown(() => toggle.value = before);
    await pumpScreen(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('OneHub Provider'), findsOneWidget);

    await tester.tap(find.text(providerSettingsToggles.first.title));
    await tester.pump();
    expect(toggle.value, !before);
  });

  testWidgets('Help & support opens the FAQ and contact details',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Help & support'));
    await tester.pumpAndSettle();

    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.text('CONTACT US'), findsOneWidget);
    expect(find.text('Frequently asked'), findsOneWidget);
  });

  testWidgets('Terms & privacy opens the text with the draft notice',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Terms & privacy'));
    await tester.pumpAndSettle();

    expect(find.byType(InfoScreen), findsOneWidget);
    expect(find.text(legalPlaceholderNotice), findsOneWidget);
    expect(find.text('Using OneHub'), findsOneWidget);
  });
}
