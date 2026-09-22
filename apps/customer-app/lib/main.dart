import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/requirements/bid_list_screen.dart';
import 'features/requirements/post_requirement_screen.dart';

void main() => runApp(const OneHubCustomerApp());

class OneHubCustomerApp extends StatelessWidget {
  const OneHubCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneHub',
      theme: OneHubTheme.light(),
      darkTheme: OneHubTheme.dark(),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
      },
      onGenerateRoute: (settings) {
        // Category browsing (CategoryGridScreen -> SubServiceListScreen) is
        // the normal path into PostRequirementScreen now; these named routes
        // remain as a direct entry point, e.g. from a push notification deep
        // link: Navigator.pushNamed(context, '/post-requirement', arguments: subServiceId).
        if (settings.name == '/post-requirement') {
          final subServiceId = settings.arguments as String;
          return MaterialPageRoute(builder: (_) => PostRequirementScreen(subServiceId: subServiceId));
        }
        if (settings.name == '/bids') {
          final requirementId = settings.arguments as String;
          return MaterialPageRoute(builder: (_) => BidListScreen(requirementId: requirementId));
        }
        return null;
      },
    );
  }
}
