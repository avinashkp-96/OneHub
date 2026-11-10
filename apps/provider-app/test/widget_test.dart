import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_provider/main.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  testWidgets('renders the login screen on launch', (tester) async {
    await tester.pumpWidget(const OneHubProviderApp());
    expect(find.text('OneHub for Providers'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('MOBILE NUMBER OR EMAIL'), findsOneWidget);
  });

  testWidgets('wires the API client to send an expired session to login',
      (tester) async {
    final client = ApiClient(baseUrl: 'https://example.test');
    await tester.pumpWidget(OneHubProviderApp(client: client));
    tester.state<NavigatorState>(find.byType(Navigator)).push(
        MaterialPageRoute(builder: (_) => const Text('SIGNED-IN PAGE')));
    await tester.pumpAndSettle();

    client.onSessionExpired!();
    await tester.pumpAndSettle();

    expect(find.text('SIGNED-IN PAGE'), findsNothing);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text(sessionExpiredMessage), findsOneWidget);
  });
}
