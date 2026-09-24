import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../requirements/active_jobs_screen.dart';

// docx 5.1 — Provider Dashboard (Home Screen).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The app bar is transparent with dark text now (OneHubTheme), not a
    // colored bar — onPrimary (meant for text on a colored background)
    // would be near-invisible here. onSurface is the app bar's own
    // foreground color.
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(
        title: const Text('OneHub Provider'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Text('Online', style: TextStyle(color: onSurface)),
                Switch(value: true, onChanged: null, activeThumbColor: context.statusSuccess),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionPlaceholder("Today's Summary — new requests, earnings, active jobs"),
          _SectionPlaceholder(
            'Incoming Requests (Accept / Reject)',
            onTap: () => Navigator.of(context).pushNamed('/incoming-requests'),
          ),
          _SectionPlaceholder(
            'Active Jobs',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActiveJobsScreen())),
          ),
          const _SectionPlaceholder('Wallet / Subscription Status'),
          const _SectionPlaceholder('Certification progress'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(OneHubIcons.home), label: 'Home'),
          NavigationDestination(icon: Icon(OneHubIcons.work), label: 'Requests'),
          NavigationDestination(icon: Icon(OneHubIcons.wallet), label: 'Earnings'),
          NavigationDestination(icon: Icon(OneHubIcons.notification), label: 'Notifications'),
          NavigationDestination(icon: Icon(OneHubIcons.profile), label: 'Profile'),
        ],
        selectedIndex: 0,
        onDestinationSelected: (_) {},
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _SectionPlaceholder(this.label, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(padding: const EdgeInsets.all(20), child: Text(label)),
      ),
    );
  }
}
