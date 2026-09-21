import 'package:flutter/material.dart';

// docx 4.1 — Customer Dashboard (Home Screen). Each section below is a
// placeholder for the corresponding widget: location/search header, category
// grid, "Post a Requirement" CTA, active request cards, nearby provider
// carousel, and the bottom nav (Home | Search | My Requests | Notifications
// | Profile).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OneHub')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionPlaceholder('Location + Search bar'),
          _SectionPlaceholder('Service Categories grid'),
          _ProminentCtaPlaceholder('Post a Requirement'),
          _SectionPlaceholder('Active Requests'),
          _SectionPlaceholder('Nearby / Recommended Providers'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'My Requests'),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(label),
      ),
    );
  }
}

// docx 4.1 describes this as "Prominent CTA button that starts the 'Describe
// your requirement' flow directly" — styled to stand out from the other
// placeholder sections even before category browsing exists to wire it up.
class _ProminentCtaPlaceholder extends StatelessWidget {
  final String label;
  const _ProminentCtaPlaceholder(this.label);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.add_circle, color: colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
