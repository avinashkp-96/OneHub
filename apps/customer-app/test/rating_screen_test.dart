import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/features/requirements/rating_screen.dart';
import 'package:onehub_shared/onehub_shared.dart';

import 'support/fake_api.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester,
      {void Function(bool?)? onResult}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OneHubTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) => const RatingScreen(
                            requirementId: 'req-1', providerId: 'prov-1')),
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

  testWidgets('shows the heading, 5 stars, and the feedback field label',
      (tester) async {
    installFakeApi({});
    await pumpScreen(tester);

    expect(find.text('Rate this service'), findsOneWidget);
    expect(find.byIcon(OneHubIcons.starOutline), findsNWidgets(5));
    expect(find.textContaining('WRITTEN FEEDBACK'), findsOneWidget);
  });

  testWidgets('the form is a single GlowCard wrapped in PageGlow',
      (tester) async {
    installFakeApi({});
    await pumpScreen(tester);

    expect(find.byType(GlowCard), findsOneWidget);
    expect(find.byType(PageGlow), findsOneWidget);
  });

  testWidgets('tapping a star fills it in and shows its rating label',
      (tester) async {
    installFakeApi({});
    await pumpScreen(tester);

    await tester.tap(find.byIcon(OneHubIcons.starOutline).at(3));
    await tester.pump();

    expect(find.byIcon(OneHubIcons.starFilled), findsNWidgets(4));
    expect(find.text('Great'), findsOneWidget);
  });

  testWidgets('the submit button is the PrimaryCta labeled Submit Rating',
      (tester) async {
    installFakeApi({});
    await pumpScreen(tester);

    expect(find.widgetWithText(PrimaryCta, 'Submit Rating'), findsOneWidget);
  });

  testWidgets('asks for a star rating before submitting', (tester) async {
    final fake = installFakeApi({});
    await pumpScreen(tester);

    await tester.tap(find.widgetWithText(PrimaryCta, 'Submit Rating'));
    await tester.pump();

    expect(find.text('Select a star rating.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('submits the stars and feedback, then closes with true',
      (tester) async {
    bool? result;
    final fake = installFakeApi({
      'POST /ratings': (_) => {'id': 'x'}
    });
    await pumpScreen(tester, onResult: (r) => result = r);

    await tester.tap(find.byIcon(OneHubIcons.starOutline).at(3));
    await tester.enterText(
        find.widgetWithText(TextField, 'What stood out about this job?'),
        ' Quick and tidy ');
    await tester.tap(find.widgetWithText(PrimaryCta, 'Submit Rating'));
    await tester.pumpAndSettle();

    expect(fake.bodies.single, {
      'requirementId': 'req-1',
      'providerId': 'prov-1',
      'stars': 4,
      'feedback': 'Quick and tidy',
    });
    expect(result, isTrue);
    expect(find.byType(RatingScreen), findsNothing);
  });

  testWidgets('leaves feedback out when none is written', (tester) async {
    final fake = installFakeApi({
      'POST /ratings': (_) => {'id': 'x'}
    });
    await pumpScreen(tester);

    await tester.tap(find.byIcon(OneHubIcons.starOutline).first);
    await tester.tap(find.widgetWithText(PrimaryCta, 'Submit Rating'));
    await tester.pumpAndSettle();

    expect(fake.bodies.single.containsKey('feedback'), isFalse);
    expect(fake.bodies.single['stars'], 1);
  });

  testWidgets('shows an error and stays open when submitting fails',
      (tester) async {
    installFakeApi({'POST /ratings': (_) => const FakeError(500, 'down')});
    await pumpScreen(tester);

    await tester.tap(find.byIcon(OneHubIcons.starOutline).first);
    await tester.tap(find.widgetWithText(PrimaryCta, 'Submit Rating'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not submit your rating'), findsOneWidget);
    expect(find.byType(RatingScreen), findsOneWidget);
  });
}
