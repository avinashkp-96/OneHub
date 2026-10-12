import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tallView(tester);
    await tester
        .pumpWidget(MaterialApp(theme: OneHubTheme.dark(), home: screen));
  }

  group('HelpScreen', () {
    testWidgets('shows contact details and collapsed questions',
        (tester) async {
      await pump(
        tester,
        const HelpScreen(
          faqs: [FaqItem('How do bids work?', 'Providers send a price range.')],
          supportEmail: 'help@example.com',
          supportPhone: '+91 90000 00000',
        ),
      );

      expect(find.byType(PageGlow), findsOneWidget);
      expect(find.byType(GlowCard), findsOneWidget);
      expect(find.text('Help & support'), findsOneWidget);
      expect(find.text('help@example.com'), findsOneWidget);
      expect(find.text('+91 90000 00000'), findsOneWidget);
      expect(find.text('How do bids work?'), findsOneWidget);
      expect(find.text('Providers send a price range.'), findsNothing);
    });

    testWidgets('tapping a question reveals its answer', (tester) async {
      await pump(
        tester,
        const HelpScreen(
          faqs: [FaqItem('How do bids work?', 'Providers send a price range.')],
          supportEmail: 'a@b.co',
          supportPhone: '1',
        ),
      );

      await tester.tap(find.text('How do bids work?'));
      await tester.pumpAndSettle();

      expect(find.text('Providers send a price range.'), findsOneWidget);
    });

    testWidgets('says so when there are no questions', (tester) async {
      await pump(
        tester,
        const HelpScreen(faqs: [], supportEmail: 'a@b.co', supportPhone: '1'),
      );

      expect(find.text('No questions yet.'), findsOneWidget);
    });
  });

  group('InfoScreen', () {
    testWidgets('shows the title, notice and every section', (tester) async {
      await pump(
        tester,
        const InfoScreen(
          title: 'Terms',
          subtitle: 'The rules.',
          notice: legalPlaceholderNotice,
          sections: [
            InfoSection('One', 'First body'),
            InfoSection('Two', 'Second body')
          ],
        ),
      );

      expect(find.byType(GlowCard), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text(legalPlaceholderNotice), findsOneWidget);
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Second body'), findsOneWidget);
    });

    testWidgets('omits the notice when none is given', (tester) async {
      await pump(
        tester,
        const InfoScreen(
            title: 'Privacy',
            subtitle: 'Your data.',
            sections: [InfoSection('One', 'Body')]),
      );

      expect(find.text(legalPlaceholderNotice), findsNothing);
    });

    test('placeholder legal content is non-empty', () {
      expect(onehubTermsSections, isNotEmpty);
      expect(onehubPrivacySections, isNotEmpty);
    });
  });
}
