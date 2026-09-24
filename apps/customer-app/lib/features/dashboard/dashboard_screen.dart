import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../categories/category_grid_screen.dart';
import '../requirements/my_requests_screen.dart';

// docx 4.1 — Customer Dashboard (Home Screen). Structure and section
// rhythm (location chip + bell, headline, search + filter, hero CTA card,
// Services quick-access grid, Active Requests with a status stepper,
// Nearby Providers teaser, promo banner) follow an explicit HTML/CSS
// reference the user supplied directly ("OneHub home screen.html") —
// matched for layout/alignment only. Colors, fonts, and icons stay the
// current OneHub design system (OneHubColors/OneHubTheme/OneHubIcons) per
// explicit instruction, not the reference's own beige/mint palette or
// custom SVG icon set. Services and Active Requests are wired to the real
// /categories and /requirements/mine endpoints (data this app already
// fetches elsewhere) rather than the reference's example content, since
// that's specific fabricated sample data (names, ratings, distances) with
// no backing endpoint. Nearby Providers has no matching generic endpoint
// (providers.controller.ts only supports GET /providers?subServiceId=...,
// scoped to one sub-service) — kept as a prompt into category browsing
// instead of inventing example providers.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<ServiceCategory> _categories = [];
  List<Requirement> _requirements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait(
          [api.get('/categories'), api.get('/requirements/mine')]);
      if (!mounted) return;
      setState(() {
        _categories = (results[0] as List)
            .map((c) => ServiceCategory.fromJson(c as Map<String, dynamic>))
            .toList();
        _requirements = (results[1] as List)
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
                    title: 'Services',
                    actionLabel: 'See all',
                    onAction: openCategories),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()))
                else
                  _ServicesGrid(categories: _categories, onTap: openCategories),
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
                Text('Set your location',
                    style: OneHubTextStyles.linkText(textPrimary)),
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
    return Text('What needs fixing today?',
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

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusInputField),
        border: Border.all(color: inputBorder),
      ),
      child: Row(
        children: [
          Icon(OneHubIcons.search, color: textMuted, size: 20),
          const SizedBox(width: OneHubTheme.gapIconLabel + 4),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text('Search for electricians, plumbers...',
                  style: OneHubTextStyles.bodyText(textMuted)),
            ),
          ),
          IconButton(
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: OneHubColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(OneHubTheme.radiusInputField - 5)),
            ),
            icon: const Icon(OneHubIcons.category, size: 18),
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [OneHubColors.primary, OneHubColors.primaryGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Transform.rotate(
              angle: -0.3,
              child: Icon(OneHubIcons.work,
                  size: 140, color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tell us what's broken",
                style: OneHubTextStyles.pageHeading(Colors.white)
                    .copyWith(fontSize: 22),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 230,
                child: Text(
                  'Describe the job once and nearby pros send you bids.',
                  style: OneHubTextStyles.bodyText(
                      Colors.white.withValues(alpha: 0.85)),
                ),
              ),
              const SizedBox(height: 18),
              InkWell(
                borderRadius:
                    BorderRadius.circular(OneHubTheme.radiusCtaButton),
                onTap: onTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(OneHubTheme.radiusCtaButton)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(OneHubIcons.plus,
                          size: 18, color: OneHubColors.primary),
                      const SizedBox(width: 8),
                      Text('Describe your requirement',
                          style: OneHubTextStyles.buttonLabel(
                              OneHubColors.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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

const _categoryTintPalette = [
  OneHubColors.primary,
  OneHubColors.accentPurple,
  OneHubColors.success,
  OneHubColors.warning,
  OneHubColors.danger,
];

class _ServicesGrid extends StatelessWidget {
  final List<ServiceCategory> categories;
  final VoidCallback onTap;
  const _ServicesGrid({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      final textMuted =
          dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
      return Text('Services aren\'t available right now.',
          style: OneHubTextStyles.bodyText(textMuted));
    }

    final shown = categories.take(8).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final category = shown[index];
        final tint = _categoryTintPalette[index % _categoryTintPalette.length];
        return _CategoryQuickTile(
            name: category.name, tint: tint, onTap: onTap);
      },
    );
  }
}

class _CategoryQuickTile extends StatelessWidget {
  final String name;
  final Color tint;
  final VoidCallback onTap;
  const _CategoryQuickTile(
      {required this.name, required this.tint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: tint.withValues(alpha: 0.15)),
            child: Icon(OneHubIcons.category, color: tint, size: 24),
          ),
          const SizedBox(height: 7),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: OneHubTextStyles.fieldLabel(textPrimary)
                .copyWith(letterSpacing: 0, fontSize: 11),
          ),
        ],
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
