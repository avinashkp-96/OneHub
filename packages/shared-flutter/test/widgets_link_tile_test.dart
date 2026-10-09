import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  testWidgets('shows title and caption and reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: OneHubTheme.dark(),
      home: Scaffold(
        body: OneHubLinkTile(
          icon: OneHubIcons.calendar,
          title: 'Availability',
          subtitle: 'Hours and area',
          onTap: () => taps++,
        ),
      ),
    ));

    expect(find.text('Availability'), findsOneWidget);
    expect(find.text('Hours and area'), findsOneWidget);
    expect(find.byIcon(OneHubIcons.chevronRight), findsOneWidget);
    expect(find.byType(GlowCard), findsNothing);

    await tester.tap(find.text('Availability'));
    expect(taps, 1);
  });
}
