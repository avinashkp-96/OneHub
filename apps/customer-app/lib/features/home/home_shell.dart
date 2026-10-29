import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../categories/category_grid_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../requirements/my_requests_screen.dart';

/// Indexes of the bottom bar's tabs.
abstract final class HomeTab {
  static const home = 0;
  static const requests = 1;
  static const category = 2;
  static const profile = 3;
}

const homeTabItems = [
  CurvedNavItem(icon: OneHubIcons.home, label: 'Home'),
  CurvedNavItem(icon: OneHubIcons.documentList, label: 'Requests'),
  CurvedNavItem(icon: OneHubIcons.category, label: 'Category'),
  CurvedNavItem(icon: OneHubIcons.profile, label: 'Profile'),
];

/// The signed-in home: the bottom bar stays on screen and swaps between its
/// four first pages (Home, My requests, categories, Profile), with the active
/// tab highlighted. Anything opened from a tab is pushed over the whole shell,
/// so deeper pages have a back arrow and no bottom bar.
///
/// Each tab is rebuilt when selected, so its data is fresh every time (the
/// Home requests list included). Back on any other tab returns to Home
/// instead of leaving the app.
class HomeShell extends StatefulWidget {
  final int initialTab;
  const HomeShell({super.key, this.initialTab = HomeTab.home});

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
    final Widget page = switch (_tab) {
      HomeTab.requests => const MyRequestsScreen(asTab: true),
      HomeTab.category => const CategoryGridScreen(asTab: true),
      HomeTab.profile => const ProfileScreen(asTab: true),
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
