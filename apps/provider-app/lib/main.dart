import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import 'core/api.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';
import 'features/requirements/incoming_requests_screen.dart';

void main() => runApp(const OneHubProviderApp());

final _navigator = GlobalKey<NavigatorState>();
final _messenger = GlobalKey<ScaffoldMessengerState>();

class OneHubProviderApp extends StatelessWidget {
  final ApiClient? client;
  const OneHubProviderApp({super.key, this.client});

  @override
  Widget build(BuildContext context) {
    sendToLoginOnSessionExpiry(client ?? api, _navigator, _messenger);
    return MaterialApp(
      navigatorKey: _navigator,
      scaffoldMessengerKey: _messenger,
      title: 'OneHub Provider',
      debugShowCheckedModeBanner: false,
      theme: OneHubTheme.light(),
      darkTheme: OneHubTheme.dark(),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const HomeShell(),
        '/incoming-requests': (_) => const IncomingRequestsScreen(),
      },
    );
  }
}
