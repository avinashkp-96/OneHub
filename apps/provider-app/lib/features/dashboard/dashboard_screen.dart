import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../certification/certification_screen.dart';
import '../profile/profile_screen.dart';
import '../requirements/active_jobs_screen.dart';

// docx 5.1 — Provider Dashboard (Home Screen). Restyled to match the
// customer dashboard's structure (header row, headline, one GlowCard hero,
// tile sections, floating nav bar), no new reference — applied on request.
//
// Every number and name on this screen is explicit dummy data, as agreed
// when the redesign was scoped: none of today's summary, earnings, wallet,
// subscription or certification figures have an API behind them yet. The
// two job tiles still open the real, API-backed screens. Replace the
// `_dummy*` constants below with live values as endpoints appear.
const _dummyProviderName = 'Asha';
const _dummyNewRequests = 3;
const _dummyActiveJobs = 2;
const _dummyEarnedToday = '₹1,850';
const _dummyWalletBalance = '₹1,250';
const _dummyPlan = 'PRO PLAN';
const _dummyRenewal = 'Renews 12 Nov';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void openRequests() =>
        Navigator.of(context).pushNamed('/incoming-requests');
    void openJobs() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ActiveJobsScreen()));
    void openProfile() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfileScreen()));

    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Scaffold(
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                OneHubTheme.pageMargin, 20, OneHubTheme.pageMargin, 100),
            children: [
              const _TopRow(),
              const SizedBox(height: 20),
              Text('Hello, $_dummyProviderName',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 28)),
              const SizedBox(height: 6),
              Text("Here's how today is going.",
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              const _SummaryCard(),
              const SizedBox(height: 26),
              _SectionTitle('Your work', color: textPrimary),
              const SizedBox(height: 12),
              _ActionTile(
                icon: OneHubIcons.work,
                title: 'Incoming requests',
                subtitle: 'Accept or reject new jobs',
                badge: '$_dummyNewRequests NEW',
                onTap: openRequests,
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: OneHubIcons.documentList,
                title: 'Active jobs',
                subtitle: 'Track and finish your jobs',
                badge: '$_dummyActiveJobs ACTIVE',
                onTap: openJobs,
              ),
              const SizedBox(height: 26),
              _SectionTitle('Wallet', color: textPrimary),
              const SizedBox(height: 12),
              const _WalletCard(),
              const SizedBox(height: 26),
              _SectionTitle('Certification', color: textPrimary),
              const SizedBox(height: 12),
              const _CertificationCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CurvedNavBar(
        items: const [
          CurvedNavItem(icon: OneHubIcons.home, label: 'Home'),
          CurvedNavItem(icon: OneHubIcons.work, label: 'Requests'),
          CurvedNavItem(icon: OneHubIcons.documentList, label: 'Jobs'),
          CurvedNavItem(icon: OneHubIcons.profile, label: 'Profile'),
        ],
        selectedIndex: 0,
        // Index 0 is this screen, so there's nothing to open for it.
        onSelected: (index) {
          if (index == 1) openRequests();
          if (index == 2) openJobs();
          if (index == 3) openProfile();
        },
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final cardFill =
        dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final cardBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return Row(
      children: [
        // Display-only: going offline isn't wired to the backend yet, which
        // is also why the old switch was permanently disabled.
        TintedBadge(
            label: '● ONLINE', color: context.statusSuccess, pill: true),
        const Spacer(),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cardFill,
                  border: Border.all(color: cardBorder)),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon:
                    Icon(OneHubIcons.notification, size: 18, color: textMuted),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Notifications aren't set up yet."))),
              ),
            ),
            Positioned(
              top: 2,
              right: 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.statusDanger,
                  border: Border.all(
                      color: dark
                          ? OneHubColors.surfaceDark
                          : OneHubColors.surfaceLight,
                      width: 2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final divider =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 22)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: OneHubTextStyles.fieldLabel(textMuted)),
            ],
          ),
        );

    return GlowCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: OneHubTheme.cardPadding, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TintedBadge(
                label: "TODAY'S SUMMARY", color: OneHubColors.primary),
            const SizedBox(height: 18),
            Row(
              children: [
                stat('$_dummyNewRequests', 'NEW REQUESTS'),
                Container(width: 1, height: 36, color: divider),
                stat('$_dummyActiveJobs', 'ACTIVE JOBS'),
                Container(width: 1, height: 36, color: divider),
                stat(_dummyEarnedToday, 'EARNED TODAY'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionTitle(this.text, {required this.color});

  @override
  Widget build(BuildContext context) => Text(text,
      style: OneHubTextStyles.pageHeading(color).copyWith(fontSize: 18));
}

class _IconCircle extends StatelessWidget {
  final IconData icon;
  const _IconCircle(this.icon);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final fill = dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final border =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: Border.all(color: border)),
      child: Icon(icon, color: textPrimary, size: 18),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _IconCircle(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: OneHubTextStyles.bodyText(textPrimary).copyWith(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: OneHubTextStyles.fieldLabel(textMuted)
                            .copyWith(letterSpacing: 0, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TintedBadge(label: badge, color: context.statusWarning),
              const SizedBox(width: 8),
              Icon(OneHubIcons.chevronRight, size: 18, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const _IconCircle(OneHubIcons.wallet),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wallet balance',
                      style: OneHubTextStyles.fieldLabel(textMuted)),
                  const SizedBox(height: 2),
                  Text(_dummyWalletBalance,
                      style: OneHubTextStyles.pageHeading(textPrimary)
                          .copyWith(fontSize: 22)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TintedBadge(
                    label: _dummyPlan,
                    color: context.statusSuccess,
                    pill: true),
                const SizedBox(height: 4),
                Text(_dummyRenewal,
                    style: OneHubTextStyles.fieldLabel(textMuted)
                        .copyWith(letterSpacing: 0, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificationCard extends StatelessWidget {
  const _CertificationCard();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final lineColor =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    final total = certificationSteps.length;
    final done = certificationStepsDone;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CertificationScreen())),
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Get certified',
                        style: OneHubTextStyles.bodyText(textPrimary).copyWith(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  Text('$done of $total steps',
                      style: OneHubTextStyles.fieldLabel(textMuted)),
                  const SizedBox(width: 8),
                  Icon(OneHubIcons.chevronRight, size: 18, color: textMuted),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < total; i++)
                    Expanded(
                      child: Container(
                        height: 5,
                        margin: EdgeInsets.only(right: i == total - 1 ? 0 : 5),
                        decoration: BoxDecoration(
                          color: i < done ? OneHubColors.primary : lineColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Certified providers get more requests.',
                  style: OneHubTextStyles.fieldLabel(textMuted)
                      .copyWith(letterSpacing: 0, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
