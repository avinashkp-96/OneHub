import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../categories/category_grid_screen.dart';
import '../requirements/my_requests_screen.dart';

// docx 4.1 — Customer Dashboard (Home Screen). Structure follows an
// explicit HTML/CSS reference the user supplied ("OneHub home screen.html"),
// matched for layout/alignment only, plus a second, pixel-exact screenshot
// round for the header/search/hero/Services section specifically. Colors,
// fonts, and icons stay the current OneHub design system
// (OneHubColors/OneHubTheme/OneHubIcons) per explicit instruction. The
// Services grid uses explicit dummy data (name/icon/pro count) per that
// screenshot's own instruction ("use dummy data for now") — "available
// pros" has no backing field on ServiceCategory regardless, so this is the
// only way to show it right now; "See all" still opens the real,
// API-backed CategoryGridScreen. Active Requests stays wired to the real
// /requirements/mine endpoint (unaffected by that screenshot, which didn't
// show this section). Nearby Providers has no matching generic endpoint
// (providers.controller.ts only supports GET /providers?subServiceId=...,
// scoped to one sub-service) — kept as a prompt into category browsing
// instead of inventing example providers.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Requirement> _requirements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await api.get('/requirements/mine') as List;
      if (!mounted) return;
      setState(() {
        _requirements = json
            .map((r) => Requirement.fromJson(r as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    void openCategories() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CategoryGridScreen()));
    void openMyRequests() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyRequestsScreen()));

    return Scaffold(
      body: PageGlow(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  OneHubTheme.pageMargin, 20, OneHubTheme.pageMargin, 100),
              children: [
                _TopRow(),
                const SizedBox(height: 20),
                _Headline(),
                const SizedBox(height: OneHubTheme.sectionGap),
                _SearchBar(onTap: openCategories),
                const SizedBox(height: OneHubTheme.sectionGap),
                _HeroCard(onTap: openCategories),
                const SizedBox(height: 26),
                _SectionHeader(
                    title: 'Expert services',
                    actionLabel: 'See all',
                    onAction: openCategories),
                const SizedBox(height: 12),
                _ServicesGrid(onTap: openCategories),
                const SizedBox(height: 26),
                _SectionHeader(
                    title: 'Active requests',
                    actionLabel: 'View all',
                    onAction: openMyRequests),
                const SizedBox(height: 12),
                if (!_loading)
                  _ActiveRequestsSection(
                      requirements: _requirements, onOpen: openMyRequests),
                const SizedBox(height: 26),
                _SectionHeader(
                    title: 'Nearby providers',
                    actionLabel: 'See all',
                    onAction: openCategories),
                const SizedBox(height: 12),
                _NearbyProvidersPrompt(onTap: openCategories),
                const SizedBox(height: 22),
                const _PromoBanner(),
              ],
            ),
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

// --- Header row: location chip + notification bell -------------------------

class _TopRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final cardFill =
        dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final cardBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(OneHubTheme.radiusPillBadge),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Location detection isn't set up yet."))),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            decoration: BoxDecoration(
              color: cardFill,
              borderRadius: BorderRadius.circular(OneHubTheme.radiusPillBadge),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(OneHubIcons.location,
                    size: 16, color: OneHubColors.primary),
                const SizedBox(width: 6),
                // Dummy location text — geolocation isn't wired up yet, but
                // the reference screenshot calls for a real-looking value
                // here rather than a generic "Set your location" prompt.
                Text('Edappally, Kochi',
                    style: OneHubTextStyles.linkText(textPrimary)),
                const SizedBox(width: 2),
                Icon(OneHubIcons.chevronDown, size: 14, color: textMuted),
              ],
            ),
          ),
        ),
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

class _Headline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    // "Meera" is dummy placeholder content per the reference screenshot —
    // no real user name is plumbed through to this screen yet.
    return Text('What needs fixing today, Meera?',
        style:
            OneHubTextStyles.pageHeading(textPrimary).copyWith(fontSize: 28));
  }
}

// --- Search bar with a trailing filter button -------------------------------

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final inputFill =
        dark ? OneHubColors.inputFillDark : OneHubColors.inputFillLight;
    final inputBorder =
        dark ? OneHubColors.inputBorderDark : OneHubColors.inputBorderLight;

    final filterFill =
        dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final filterBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        border: Border.all(color: inputBorder),
      ),
      child: Row(
        children: [
          Icon(OneHubIcons.search, color: textMuted, size: 20),
          const SizedBox(width: OneHubTheme.gapIconLabel + 4),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text('Search electrician, plumber...',
                  style: OneHubTextStyles.bodyText(textMuted)),
            ),
          ),
          IconButton(
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: filterFill,
              foregroundColor: textPrimary,
              side: BorderSide(color: filterBorder),
              shape: const CircleBorder(),
            ),
            icon: const Icon(OneHubIcons.filter, size: 18),
          ),
        ],
      ),
    );
  }
}

// --- Hero CTA card -----------------------------------------------------------

class _HeroCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final ctaFill =
        dark ? OneHubColors.navBarFillDark : OneHubColors.navBarFillLight;

    return GlowCard(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: OneHubColors.warning.withValues(alpha: 0.14),
                borderRadius:
                    BorderRadius.circular(OneHubTheme.radiusPillBadge),
                border: Border.all(
                    color: OneHubColors.warning.withValues(alpha: 0.22)),
              ),
              child: Text(
                'FREE TO POST',
                style: OneHubTextStyles.badgeLabel(OneHubColors.warning)
                    .copyWith(letterSpacing: 0, fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "Tell us what's broken",
              style: OneHubTextStyles.pageHeading(textPrimary)
                  .copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 230,
              child: Text(
                'Describe the job once and nearby pros send you bids.',
                style: OneHubTextStyles.bodyText(textSecondary),
              ),
            ),
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(OneHubTheme.radiusPillBadge),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
                decoration: BoxDecoration(
                    color: ctaFill,
                    borderRadius:
                        BorderRadius.circular(OneHubTheme.radiusPillBadge)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.white),
                      child: const Center(
                        child: Icon(OneHubIcons.chevronRight,
                            size: 16, color: OneHubColors.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Post requirement',
                        style: OneHubTextStyles.buttonLabel(textPrimary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Shared "section header + action link" row -------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionHeader(
      {required this.title, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: OneHubTextStyles.pageHeading(textPrimary)
                .copyWith(fontSize: 18)),
        GestureDetector(
          onTap: onAction,
          child: Text(actionLabel,
              style: OneHubTextStyles.linkText(OneHubColors.primary)),
        ),
      ],
    );
  }
}

// --- Services quick-access grid -----------------------------------------------
//
// Explicit dummy data ("use dummy data for now") — icon, name, and pro
// count all come from a reference screenshot, not a real endpoint.
// ServiceCategory (the real model) has no "available pros" field at all,
// so this specific stat can't be real yet regardless.

const _categoryTintPalette = [
  OneHubColors.primary,
  OneHubColors.accentPurple,
  OneHubColors.success,
  OneHubColors.warning,
  OneHubColors.danger,
];

class _DummyCategory {
  final String name;
  final IconData icon;
  final int proCount;
  const _DummyCategory(this.name, this.icon, this.proCount);
}

const _dummyCategories = [
  _DummyCategory('Electrician', OneHubIcons.danger, 18),
  _DummyCategory('Plumber', OneHubIcons.category, 24),
  _DummyCategory('Painter', OneHubIcons.edit, 31),
  _DummyCategory('Carpenter', OneHubIcons.work, 12),
];

class _ServicesGrid extends StatelessWidget {
  final VoidCallback onTap;
  const _ServicesGrid({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 130,
      ),
      itemCount: _dummyCategories.length,
      itemBuilder: (context, index) =>
          _ServiceCard(category: _dummyCategories[index], onTap: onTap),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final _DummyCategory category;
  final VoidCallback onTap;
  const _ServiceCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final iconFill =
        dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final iconBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconFill,
                    border: Border.all(color: iconBorder)),
                child: Icon(category.icon, color: textPrimary, size: 18),
              ),
              const SizedBox(height: 12),
              Text(category.name,
                  style: OneHubTextStyles.bodyText(textPrimary)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text('${category.proCount} available pros',
                  style: OneHubTextStyles.fieldLabel(textMuted)
                      .copyWith(letterSpacing: 0, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Active requests: status stepper cards ------------------------------------

class _ActiveRequestsSection extends StatelessWidget {
  final List<Requirement> requirements;
  final VoidCallback onOpen;
  const _ActiveRequestsSection(
      {required this.requirements, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    final active = requirements
        .where((r) => r.status != RequestStatus.completed)
        .take(2)
        .toList();
    if (active.isEmpty) {
      return Text("You don't have any active requests.",
          style: OneHubTextStyles.bodyText(textMuted));
    }
    return Column(children: [
      for (final r in active) _ActiveRequestCard(requirement: r, onTap: onOpen)
    ]);
  }
}

class _ActiveRequestCard extends StatelessWidget {
  final Requirement requirement;
  final VoidCallback onTap;
  const _ActiveRequestCard({required this.requirement, required this.onTap});

  static const _steps = ['Sent', 'Accepted', 'Bids', 'Confirmed'];

  int? _stepIndex(RequestStatus status) => switch (status) {
        RequestStatus.sent => 0,
        RequestStatus.accepted => 1,
        RequestStatus.bidReceived => 2,
        RequestStatus.confirmed => 3,
        _ => null, // terminal/negative statuses don't map onto this stepper
      };

  String _tagLabel(RequestStatus status) => switch (status) {
        RequestStatus.sent => 'Sent',
        RequestStatus.accepted => 'Accepted',
        RequestStatus.bidReceived => '${requirement.bids.length} bids',
        RequestStatus.confirmed => 'Confirmed',
        RequestStatus.rejected => 'Rejected',
        RequestStatus.cancelled => 'Cancelled',
        RequestStatus.expired => 'Expired',
        RequestStatus.completed => 'Completed',
      };

  Color _tagColor(BuildContext context, RequestStatus status) =>
      switch (status) {
        RequestStatus.confirmed ||
        RequestStatus.completed =>
          context.statusSuccess,
        RequestStatus.bidReceived => context.statusWarning,
        RequestStatus.rejected ||
        RequestStatus.cancelled ||
        RequestStatus.expired =>
          context.statusDanger,
        _ => OneHubColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final lineColor =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final tagColor = _tagColor(context, requirement.status);
    final step = _stepIndex(requirement.status);

    return GlowCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      requirement.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OneHubTextStyles.bodyText(textPrimary)
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.16),
                        borderRadius:
                            BorderRadius.circular(OneHubTheme.radiusPillBadge)),
                    child: Text(
                      _tagLabel(requirement.status),
                      style: OneHubTextStyles.badgeLabel(tagColor)
                          .copyWith(letterSpacing: 0),
                    ),
                  ),
                ],
              ),
              if (step != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      Expanded(
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(
                              right: i == _steps.length - 1 ? 0 : 5),
                          decoration: BoxDecoration(
                            color: i <= step ? OneHubColors.primary : lineColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final label in _steps)
                      Expanded(
                          child: Text(label,
                              style: OneHubTextStyles.fieldLabel(textMuted)
                                  .copyWith(letterSpacing: 0, fontSize: 10))),
                  ],
                ),
              ],
              if (requirement.status == RequestStatus.bidReceived &&
                  requirement.bids.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: lineColor))),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20.0 +
                            (requirement.bids.length.clamp(0, 3) - 1) * 14,
                        height: 26,
                        child: Stack(
                          children: [
                            for (var i = 0;
                                i < requirement.bids.length.clamp(0, 3);
                                i++)
                              Positioned(
                                left: i * 14.0,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _categoryTintPalette[
                                        i % _categoryTintPalette.length],
                                    border: Border.all(
                                      color: dark
                                          ? OneHubColors.cardFillDark
                                          : OneHubColors.cardFillLight,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(OneHubIcons.user,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: OneHubTextStyles.fieldLabel(textMuted)
                                .copyWith(letterSpacing: 0, fontSize: 12),
                            children: [
                              const TextSpan(text: 'Lowest bid '),
                              TextSpan(
                                text:
                                    '₹${_lowestBid(requirement).toStringAsFixed(0)}',
                                style: OneHubTextStyles.fieldLabel(textPrimary)
                                    .copyWith(
                                        letterSpacing: 0,
                                        fontWeight: FontWeight.w700),
                              ),
                              const TextSpan(text: ' · Compare and pick'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  double _lowestBid(Requirement r) {
    var lowest = double.infinity;
    for (final bid in r.bids) {
      final min = bid.refinedMinPrice ?? bid.initialMinPrice;
      if (min < lowest) lowest = min;
    }
    return lowest == double.infinity ? 0 : lowest;
  }
}

// --- Nearby providers: no generic endpoint yet, so this is a prompt ----------

class _NearbyProvidersPrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _NearbyProvidersPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    return Card(
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
                child: const Icon(OneHubIcons.work,
                    color: OneHubColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Browse a category',
                        style: OneHubTextStyles.bodyText(textPrimary)
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('See rated providers near you for that service',
                        style: OneHubTextStyles.fieldLabel(textMuted)
                            .copyWith(letterSpacing: 0)),
                  ],
                ),
              ),
              Icon(OneHubIcons.chevronRight, color: textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Promo banner --------------------------------------------------------------

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: OneHubColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('₹100 off your first job',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 17)),
                const SizedBox(height: 2),
                Text('Applies to any service',
                    style: OneHubTextStyles.fieldLabel(textPrimary)
                        .copyWith(letterSpacing: 0)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: OneHubColors.primary),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('ONEHUB100',
                style: OneHubTextStyles.badgeLabel(OneHubColors.primary)
                    .copyWith(letterSpacing: 0)),
          ),
        ],
      ),
    );
  }
}
