import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  testWidgets('shows the message with a check on the success colour',
      (tester) async {
    late Color success;
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            success = context.statusSuccess;
            return TextButton(
              onPressed: () => ScaffoldMessenger.of(context)
                  .showSnackBar(successSnackBar(context, 'Bid sent.')),
              child: const Text('go'),
            );
          },
        ),
      ),
    ));

    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.text('Bid sent.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, success);
    expect(bar.behavior, SnackBarBehavior.floating);
  });

  testWidgets('can be shown after the screen that built it has popped',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: Builder(
        builder: (home) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(home).push(MaterialPageRoute(
              builder: (inner) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    final messenger = ScaffoldMessenger.of(inner);
                    final bar = successSnackBar(inner, 'Saved.');
                    Navigator.of(inner).pop();
                    messenger.showSnackBar(bar);
                  },
                  child: const Text('save'),
                ),
              ),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.text('Saved.'), findsOneWidget);
  });

  testWidgets('showSuccessMessage replaces the message on screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => showSuccessMessage(context, 'First.'),
                child: const Text('one'),
              ),
              TextButton(
                onPressed: () => showSuccessMessage(context, 'Second.'),
                child: const Text('two'),
              ),
            ],
          ),
        ),
      ),
    ));

    await tester.tap(find.text('one'));
    await tester.pump();
    await tester.tap(find.text('two'));
    await tester.pumpAndSettle();

    expect(find.text('Second.'), findsOneWidget);
    expect(find.text('First.'), findsNothing);
  });
}
