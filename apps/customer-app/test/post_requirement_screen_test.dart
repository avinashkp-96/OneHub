import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/requirements/post_requirement_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  final providers = [
    {
      'id': 'p1',
      'businessName': 'Asha Electricals',
      'averageRating': 4.5,
      'certified': true
    },
    {
      'id': 'p2',
      'user': {'fullName': 'Ravi Kumar'},
      'averageRating': 3.0,
      'certified': false,
    },
  ];

  // Opens the screen from a button so a successful submit can be seen popping
  // back with `true`.
  Future<void> pumpScreen(WidgetTester tester,
      {bool? Function(bool?)? onResult}) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) =>
                            const PostRequirementScreen(subServiceId: 'sub-1')),
                  );
                  onResult?.call(result);
                },
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

  Future<void> describe(WidgetTester tester) async {
    await tester.enterText(
        find.widgetWithText(
            TextField, 'e.g. Ceiling fan making a rattling noise'),
        ' Fan is noisy ');
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(PrimaryCta, 'Send Request'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the form, with one GlowCard and the providers below it',
      (tester) async {
    installFakeApi({'GET /providers': (_) => providers});
    await pumpScreen(tester);

    expect(find.byType(PageGlow), findsOneWidget);
    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.text('Tell us what you need'), findsOneWidget);
    expect(find.text('Any time works'), findsOneWidget);
    expect(find.text('Asha Electricals'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    expect(find.text('4.5 ★'), findsOneWidget);
    expect(find.text('CERTIFIED'), findsOneWidget);
    expect(find.widgetWithText(PrimaryCta, 'Send Request'), findsOneWidget);
  });

  testWidgets('shows a loading spinner for the providers only', (tester) async {
    installFakeApi({'GET /providers': (_) => providers});
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.dark(),
        home: const PostRequirementScreen(subServiceId: 'sub-1'),
      ),
    );

    expect(find.text('Tell us what you need'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows an empty message when no providers are nearby',
      (tester) async {
    installFakeApi({'GET /providers': (_) => []});
    await pumpScreen(tester);

    expect(find.text('No providers found nearby. Try widening your search.'),
        findsOneWidget);
  });

  testWidgets('shows an error when the providers cannot be loaded',
      (tester) async {
    installFakeApi({'GET /providers': (_) => const FakeError(500, 'down')});
    await pumpScreen(tester);

    expect(find.textContaining('Could not load providers'), findsOneWidget);
  });

  testWidgets('tapping a provider selects it and tapping again clears it',
      (tester) async {
    installFakeApi({'GET /providers': (_) => providers});
    await pumpScreen(tester);

    expect(find.byIcon(OneHubIcons.confirmed), findsNothing);
    await tester.tap(find.text('Asha Electricals'));
    await tester.pump();
    expect(find.byIcon(OneHubIcons.confirmed), findsOneWidget);

    await tester.tap(find.text('Asha Electricals'));
    await tester.pump();
    expect(find.byIcon(OneHubIcons.confirmed), findsNothing);
  });

  testWidgets('needs a description and at least one provider before sending',
      (tester) async {
    final fake = installFakeApi({'GET /providers': (_) => providers});
    await pumpScreen(tester);

    await send(tester);
    expect(find.text('Describe the work and select at least one provider.'),
        findsOneWidget);

    await describe(tester);
    await send(tester);
    expect(find.text('Describe the work and select at least one provider.'),
        findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('POST')), isEmpty);
  });

  testWidgets('sends the request and returns true to the previous screen',
      (tester) async {
    bool? result;
    final fake = installFakeApi({
      'GET /providers': (_) => providers,
      'POST /requirements': (_) => {'id': 'r1'},
    });
    await pumpScreen(tester, onResult: (r) {
      result = r;
      return r;
    });
    await describe(tester);
    await tester.tap(find.text('Asha Electricals'));
    await tester.tap(find.text('Ravi Kumar'));
    await send(tester);

    expect(fake.bodies.single['subServiceId'], 'sub-1');
    expect(fake.bodies.single['description'], 'Fan is noisy');
    expect(fake.bodies.single['providerIds'], ['p1', 'p2']);
    expect(fake.bodies.single.containsKey('preferredAt'), isFalse);
    expect(result, isTrue);
    expect(find.byType(PostRequirementScreen), findsNothing);
  });

  testWidgets('includes the preferred date when one is picked', (tester) async {
    final fake = installFakeApi({
      'GET /providers': (_) => providers,
      'POST /requirements': (_) => {'id': 'r1'},
    });
    await pumpScreen(tester);
    await describe(tester);
    await tester.tap(find.text('Asha Electricals'));

    await tester.tap(find.text('Any time works'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Any time works'), findsNothing);
    await send(tester);

    expect(fake.bodies.single['preferredAt'], isNotNull);
  });

  testWidgets('cancelling the date picker leaves the date unset',
      (tester) async {
    installFakeApi({'GET /providers': (_) => providers});
    await pumpScreen(tester);

    await tester.tap(find.text('Any time works'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Any time works'), findsOneWidget);
  });

  testWidgets('shows the server error and stays on the form when sending fails',
      (tester) async {
    installFakeApi({
      'GET /providers': (_) => providers,
      'POST /requirements': (_) => const FakeError(500, 'down'),
    });
    await pumpScreen(tester);
    await describe(tester);
    await tester.tap(find.text('Asha Electricals'));
    await send(tester);

    expect(find.textContaining('Could not send the request'), findsOneWidget);
    expect(find.byType(PostRequirementScreen), findsOneWidget);
  });
}
