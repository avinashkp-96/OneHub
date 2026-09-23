import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../requirements/active_jobs_screen.dart';

// docx 5.1 — Provider Dashboard (Home Screen).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('OneHub Provider'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Text('Online', style: TextStyle(color: onPrimary)),
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
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), label: 'Notifications'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
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
        child: Padding(padding: const EdgeInsets.all(20), child: Text(label)),
      ),
    );
  }
}
