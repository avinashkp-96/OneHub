import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../categories/category_grid_screen.dart';
import '../requirements/my_requests_screen.dart';

// docx 4.1 — Customer Dashboard (Home Screen). Redesigned per explicit
// direction: a greeting header + real-looking search field instead of a
// plain AppBar and a placeholder row, richer "feature row" cards (tinted
// icon badge + title + subtitle) instead of bare labels, and a floating
// CurvedNavBar (Home | Requests | Profile, icon-only, wavy top edge) in
// place of the old 5-item Material NavigationBar. Still placeholder
// information architecture underneath — no new reference for this
// screen's actual content, just its visual/UX treatment.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void openCategories() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CategoryGridScreen()));
    void openMyRequests() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyRequestsScreen()));

    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final inputFill =
        dark ? OneHubColors.inputFillDark : OneHubColors.inputFillLight;
    final inputBorder =
        dark ? OneHubColors.inputBorderDark : OneHubColors.inputBorderLight;

    return Scaffold(
      extendBody: true,
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              OneHubTheme.pageMargin,
              20,
              OneHubTheme.pageMargin,
              100, // clears the floating CurvedNavBar
            ),
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: inputFill,
                      border: Border.all(color: inputBorder),
                    ),
                    child:
                        Icon(OneHubIcons.profile, color: textMuted, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good day',
                            style: OneHubTextStyles.bodyText(textSecondary)),
                        Text(
                          'Find trusted professionals nearby',
                          style: OneHubTextStyles.pageHeading(textPrimary)
                              .copyWith(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(OneHubIcons.notification, color: textMuted),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Notifications aren't set up yet."))),
                  ),
                ],
              ),
              const SizedBox(height: OneHubTheme.sectionGap),
              InkWell(
                onTap: openCategories,
                borderRadius:
                    BorderRadius.circular(OneHubTheme.radiusInputField),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: OneHubTheme.fieldPaddingX, vertical: 14),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius:
                        BorderRadius.circular(OneHubTheme.radiusInputField),
                    border: Border.all(color: inputBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(OneHubIcons.search, color: textMuted, size: 20),
                      const SizedBox(width: OneHubTheme.gapIconLabel + 4),
                      Text('Search for electricians, plumbers...',
                          style: OneHubTextStyles.bodyText(textMuted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: OneHubTheme.sectionGap),
              PrimaryCta(
                onPressed: openCategories,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(OneHubIcons.plus),
                    SizedBox(width: 8),
                    Text('Post a Requirement')
                  ],
                ),
              ),
              const SizedBox(height: OneHubTheme.sectionGap),
              _FeatureRow(
                title: 'Service Categories',
                subtitle: 'Browse electricians, plumbers & more',
                icon: OneHubIcons.category,
                onTap: openCategories,
              ),
              _FeatureRow(
                title: 'Active Requests',
                subtitle: 'Track the status of your requests',
                icon: OneHubIcons.documentList,
                onTap: openMyRequests,
              ),
              const _FeatureRow(
                title: 'Nearby Providers',
                subtitle: 'Top-rated professionals near you',
                icon: OneHubIcons.work,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CurvedNavBar(
        items: const [
          CurvedNavItem(icon: OneHubIcons.category, label: 'Home'),
          CurvedNavItem(icon: OneHubIcons.documentList, label: 'Requests'),
          CurvedNavItem(icon: OneHubIcons.profile, label: 'Profile'),
        ],
        selectedIndex: 0,
        // Home is this screen; Profile isn't built yet, matching the prior
        // NavigationBar's convention of leaving unbuilt destinations unwired.
        onSelected: (index) {
          if (index == 1) openMyRequests();
        },
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  const _FeatureRow(
      {required this.title,
      required this.subtitle,
      required this.icon,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: OneHubColors.primary.withValues(alpha: 0.14)),
                child: Icon(icon, color: OneHubColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: OneHubTextStyles.bodyText(textPrimary)
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: OneHubTextStyles.fieldLabel(textMuted)
                            .copyWith(letterSpacing: 0)),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(OneHubIcons.chevronRight, color: textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
