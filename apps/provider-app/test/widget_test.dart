import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_provider/main.dart';

void main() {
  testWidgets('renders the login screen on launch', (tester) async {
    await tester.pumpWidget(const OneHubProviderApp());
    expect(find.text('OneHub for Providers'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('MOBILE NUMBER OR EMAIL'), findsOneWidget);
  });
}
