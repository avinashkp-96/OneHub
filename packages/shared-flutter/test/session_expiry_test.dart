import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehub_shared/onehub_shared.dart';

void main() {
  testWidgets('an expired session clears the stack, opens /login and says why',
      (tester) async {
    final api = ApiClient(baseUrl: 'https://example.test');
    final navigator = GlobalKey<NavigatorState>();
    final messenger = GlobalKey<ScaffoldMessengerState>();
    sendToLoginOnSessionExpiry(api, navigator, messenger);

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      scaffoldMessengerKey: messenger,
      routes: {
        '/': (_) => const Scaffold(body: Text('HOME')),
        '/login': (_) => const Scaffold(body: Text('LOGIN')),
      },
    ));
    navigator.currentState!.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('DEEP PAGE'))));
    await tester.pumpAndSettle();

    api.onSessionExpired!();
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('DEEP PAGE'), findsNothing);
    expect(navigator.currentState!.canPop(), isFalse);
    expect(find.text(sessionExpiredMessage), findsOneWidget);
  });
}
