import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_customer/main.dart';

void main() {
  testWidgets('renders the login screen on launch', (tester) async {
    await tester.pumpWidget(const OneHubCustomerApp());
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('MOBILE NUMBER OR EMAIL'), findsOneWidget);
  });
}
