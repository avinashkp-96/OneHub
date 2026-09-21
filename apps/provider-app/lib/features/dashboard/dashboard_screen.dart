import 'package:flutter/material.dart';

// docx 5.1 — Provider Dashboard (Home Screen).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OneHub Provider'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(children: const [Text('Online'), Switch(value: true, onChanged: null)]),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionPlaceholder("Today's Summary — new requests, earnings, active jobs"),
          _SectionPlaceholder('Incoming Requests (Accept / Reject)'),
          _SectionPlaceholder('Active Jobs'),
          _SectionPlaceholder('Wallet / Subscription Status'),
          _SectionPlaceholder('Certification progress'),
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
  const _SectionPlaceholder(this.label);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: const EdgeInsets.all(20), child: Text(label)),
    );
  }
}
