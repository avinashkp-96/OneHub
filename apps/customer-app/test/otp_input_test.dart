import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/core/widgets/otp_input.dart';

void main() {
  Future<List<TextField>> pumpOtp(WidgetTester tester, ValueChanged<String> onChanged) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: OtpInput(onChanged: onChanged))),
    );
    return tester.widgetList<TextField>(find.byType(TextField)).toList();
  }

  testWidgets('reports the joined code as digits are entered', (tester) async {
    String? lastCode;
    await pumpOtp(tester, (code) => lastCode = code);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '4');
    await tester.pump();
    expect(lastCode, '4');

    await tester.enterText(fields.at(1), '6');
    await tester.pump();
    expect(lastCode, '46');
  });

  testWidgets('advances focus to the next box after a digit', (tester) async {
    await pumpOtp(tester, (_) {});
    final fields = find.byType(TextField);

    await tester.enterText(fields.at(0), '4');
    await tester.pump();

    final secondField = tester.widget<TextField>(fields.at(1));
    expect(secondField.focusNode?.hasFocus, isTrue);
  });

  testWidgets('moves focus back to the previous box when a box is cleared', (tester) async {
    await pumpOtp(tester, (_) {});
    final fields = find.byType(TextField);

    await tester.enterText(fields.at(0), '4');
    await tester.pump();
    await tester.enterText(fields.at(1), '6');
    await tester.pump();
    // Clearing box 1 (simulating backspace on it) should jump back to box 0.
    await tester.enterText(fields.at(1), '');
    await tester.pump();

    final firstField = tester.widget<TextField>(fields.at(0));
    expect(firstField.focusNode?.hasFocus, isTrue);
  });

  testWidgets('keeps only the last character when more than one is entered at once', (tester) async {
    String? lastCode;
    await pumpOtp(tester, (code) => lastCode = code);
    final fields = find.byType(TextField);

    await tester.enterText(fields.at(0), '99'); // e.g. a paste landing in one box
    await tester.pump();

    expect(lastCode, '9');
  });
}
