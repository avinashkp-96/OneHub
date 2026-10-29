import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../requirements/active_jobs_screen.dart';
import '../requirements/incoming_requests_screen.dart';

/// Indexes of the bottom bar's tabs.
abstract final class HomeTab {
  static const home = 0;
  static const requests = 1;
  static const jobs = 2;
  static const profile = 3;
}

const homeTabItems = [
  CurvedNavItem(icon: OneHubIcons.home, label: 'Home'),
  CurvedNavItem(icon: OneHubIcons.work, label: 'Requests'),
  CurvedNavItem(icon: OneHubIcons.documentList, label: 'Jobs'),
  CurvedNavItem(icon: OneHubIcons.profile, label: 'Profile'),
];

/// The signed-in home: the bottom bar stays on screen and swaps between its
/// four first pages (Home, Incoming requests, Active jobs, Profile), with the
/// active tab highlighted. Anything opened from a tab is pushed over the whole
/// shell, so deeper pages have a back arrow and no bottom bar.
///
/// Each tab is rebuilt when selected, so its data is fresh every time. Back
/// on any other tab returns to Home instead of leaving the app. Takes an
/// optional [client], like the provider screens, and hands it to each tab.
class HomeShell extends StatefulWidget {
  final ApiClient? client;
  final int initialTab;
  const HomeShell({super.key, this.client, this.initialTab = HomeTab.home});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _tab = widget.initialTab;

  void _open(int tab) {
    if (tab != _tab) setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final Widget page = switch (_tab) {
      HomeTab.requests => IncomingRequestsScreen(client: client, asTab: true),
      HomeTab.jobs => ActiveJobsScreen(client: client, asTab: true),
      HomeTab.profile => ProfileScreen(client: client, asTab: true),
      _ => DashboardScreen(onOpenTab: _open),
    };

    return PopScope(
      canPop: _tab == HomeTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _open(HomeTab.home);
      },
      child: Scaffold(
        body: KeyedSubtree(key: ValueKey(_tab), child: page),
        bottomNavigationBar: CurvedNavBar(
          items: homeTabItems,
          selectedIndex: _tab,
          onSelected: _open,
        ),
      ),
    );
  }
}
