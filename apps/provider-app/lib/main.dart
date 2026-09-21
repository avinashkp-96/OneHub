import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/requirements/incoming_requests_screen.dart';

void main() => runApp(const OneHubProviderApp());

class OneHubProviderApp extends StatelessWidget {
  const OneHubProviderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneHub Provider',
      theme: OneHubTheme.light(),
      darkTheme: OneHubTheme.dark(),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/incoming-requests': (_) => const IncomingRequestsScreen(),
      },
    );
  }
}
