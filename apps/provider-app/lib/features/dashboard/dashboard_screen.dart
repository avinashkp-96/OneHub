import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../certification/certification_screen.dart';
import '../earnings/earnings_screen.dart';
import '../home/home_shell.dart';
import '../../core/api.dart';
import '../requirements/active_jobs_screen.dart';

// docx 5.1 — Provider Dashboard (Home Screen). Restyled on request: a header
// row on the page background (welcome and name on the left, online toggle and
// bell on the right), then a blue overview card with two stacked layers peeking
// out below it for a 3D look, then Your work as a two-card grid, Wallet and
// Certification. The card's blue is the PrimaryCta gradient.
//
// Most numbers and names on this screen are explicit dummy data, as agreed
// when the redesign was scoped: earnings, wallet, subscription card,
// certification and the tile counts have no API behind them yet. The overview
// card's jobs done and rating are real. The two job cards open the real,
// API-backed screens. Replace the `_dummy*` constants below with live values
// as endpoints appear.
const _dummyProviderName = 'Asha';
const _dummyNewRequests = 3;
const _dummyActiveJobs = 2;

//
// The bottom bar lives in HomeShell, which shows this screen as its Home tab
// and passes [onOpenTab] so the Incoming requests and Active jobs cards switch
// tabs. Without it (e.g. in a test), they push the screen instead.
class DashboardScreen extends StatelessWidget {
  final ValueChanged<int>? onOpenTab;

  /// Optional, like the other provider screens, so tests can use a fake API.
  final ApiClient? client;
  const DashboardScreen({super.key, this.onOpenTab, this.client});

  @override
  Widget build(BuildContext context) {
    final openTab = onOpenTab;
    void openRequests() => openTab != null
        ? openTab(HomeTab.requests)
        : Navigator.of(context).pushNamed('/incoming-requests');
    void openJobs() => openTab != null
        ? openTab(HomeTab.jobs)
        : Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ActiveJobsScreen()));

    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;

    return Scaffold(
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                OneHubTheme.pageMargin, 20, OneHubTheme.pageMargin, 100),
            children: [
              _TopRow(client: client),
              const SizedBox(height: OneHubTheme.sectionGap),
              _OverviewCard(client: client),
              const SizedBox(height: 26),
              _SectionTitle('Your work', color: textPrimary),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _WorkCard(
                        icon: OneHubIcons.work,
                        title: 'Incoming requests',
                        subtitle: 'Accept or reject new jobs',
                        badge: '$_dummyNewRequests NEW',
                        onTap: openRequests,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _WorkCard(
                        icon: OneHubIcons.documentList,
                        title: 'Active jobs',
                        subtitle: 'Track and finish your jobs',
                        badge: '$_dummyActiveJobs ACTIVE',
                        onTap: openJobs,
                      ),
                    ),
                  ],
                ),
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
    );
  }
}

/// Avatar initial, "Welcome back" and the name on the left; the online/offline
/// toggle and the bell on the right.
class _TopRow extends StatefulWidget {
  final ApiClient? client;
  const _TopRow({this.client});

  @override
  State<_TopRow> createState() => _TopRowState();
}

class _TopRowState extends State<_TopRow> {
  // Local only: there is no availability endpoint yet, so this resets when
  // the dashboard is rebuilt. Wire to the backend when one exists.
  bool _online = true;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [OneHubColors.primary, OneHubColors.primaryGradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Text(_dummyProviderName[0],
              style: OneHubTextStyles.pageHeading(Colors.white)
                  .copyWith(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back',
                  style: OneHubTextStyles.bodyText(textSecondary)
                      .copyWith(fontSize: 13)),
              Text(_dummyProviderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 20)),
            ],
          ),
        ),
        _StatusToggle(
            online: _online, onTap: () => setState(() => _online = !_online)),
        const SizedBox(width: 8),
        NotificationBell(api: widget.client ?? api),
      ],
    );
  }
}

/// Online/offline pill: a green dot when online, a grey one when offline.
/// Tapping it switches.
class _StatusToggle extends StatelessWidget {
  final bool online;
  final VoidCallback onTap;
  const _StatusToggle({required this.online, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final border =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final color = online ? context.statusSuccess : textMuted;

    return Semantics(
      button: true,
      toggled: online,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 6),
              Text(online ? 'Online' : 'Offline',
                  style: OneHubTextStyles.bodyText(color).copyWith(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The blue card under the header, with two lighter layers stacked behind it
/// for depth. Top: earned this month (still dummy, shared with the Earnings
/// screen; no earnings endpoint) and a wallet button that opens Earnings.
/// Bottom strip: jobs done (counted from GET /requirements/incoming) and
/// rating (GET /ratings/mine). Each real figure loads on its own and shows
/// "–" until it arrives or if it fails, so one slow or broken call never
/// blanks the card.
class _OverviewCard extends StatefulWidget {
  final ApiClient? client;
  const _OverviewCard({this.client});

  @override
  State<_OverviewCard> createState() => _OverviewCardState();
}

class _OverviewCardState extends State<_OverviewCard> {
  ApiClient get _api => widget.client ?? api;

  String _rating = '–';
  String _jobsDone = '–';

  @override
  void initState() {
    super.initState();
    _loadRating();
    _loadJobsDone();
  }

  Future<void> _loadRating() async {
    try {
      final json = await _api.get('/ratings/mine') as Map<String, dynamic>;
      final count = (json['ratingCount'] as num).toInt();
      final average = (json['averageRating'] as num).toDouble();
      if (!mounted) return;
      setState(() => _rating = count == 0 ? 'New' : average.toStringAsFixed(1));
    } catch (_) {
      // Keep the placeholder; the Ratings screen shows the error.
    }
  }

  // A job is done when the request is completed and this provider's bid was
  // the one confirmed; the same rule Active jobs uses for its COMPLETED badge.
  Future<void> _loadJobsDone() async {
    try {
      final json = await _api.get('/requirements/incoming') as List;
      final done = json
          .map((r) => Requirement.fromJson(r as Map<String, dynamic>))
          .where((r) =>
              r.status == RequestStatus.completed &&
              r.bids.isNotEmpty &&
              r.bids.first.confirmed)
          .length;
      if (!mounted) return;
      setState(() => _jobsDone = '$done');
    } catch (_) {
      // Keep the placeholder; Active jobs shows the error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final soft = Colors.white.withValues(alpha: 0.75);
    final glass = Colors.white.withValues(alpha: 0.16);
    // The stats strip: a solid light blue, picked on request.
    const strip = Color(0xFF528EF8);
    final radius = BorderRadius.circular(OneHubTheme.radiusFormCard);
    final rated = _rating != '–' && _rating != 'New';

    Widget layer(double alpha) => DecoratedBox(
          decoration: BoxDecoration(
            color: OneHubColors.primaryDark.withValues(alpha: alpha),
            borderRadius: radius,
          ),
        );

    Widget stat(IconData icon, String value, String label) => Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(value,
                  style: OneHubTextStyles.bodyText(Colors.white).copyWith(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OneHubTextStyles.bodyText(soft)
                        .copyWith(fontSize: 13)),
              ),
            ],
          ),
        );

    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Earned this month',
                        style: OneHubTextStyles.bodyText(soft)
                            .copyWith(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(dummyEarnedMonth,
                        style: OneHubTextStyles.pageHeading(Colors.white)
                            .copyWith(fontSize: 30)),
                  ],
                ),
              ),
              Material(
                color: glass,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Earnings',
                  icon: const Icon(OneHubIcons.wallet,
                      size: 20, color: Colors.white),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const EarningsScreen())),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            key: const Key('overview-stats'),
            // Opaque, so the card's ring pattern does not show through it.
            decoration: BoxDecoration(color: strip, borderRadius: radius),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  stat(OneHubIcons.work, _jobsDone, 'Jobs done'),
                  VerticalDivider(
                      width: 1, color: Colors.white.withValues(alpha: 0.3)),
                  stat(rated ? OneHubIcons.starFilled : OneHubIcons.starOutline,
                      _rating, 'Rating'),
                ],
              ),
            ),
          ),
        ],
    );

    final card = Container(
      key: const Key('overview-card'),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [OneHubColors.primary, OneHubColors.primaryGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(
                  key: Key('overview-pattern'), painter: _CardPattern()),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: content,
            ),
          ],
        ),
      ),
    );

    // The two layers sit lower and narrower than the card, so their bottom
    // edges peek out like a stack.
    return Stack(
      key: const Key('overview-stack'),
      children: [
        Positioned(left: 28, right: 28, top: 20, bottom: 0, child: layer(0.3)),
        Positioned(left: 14, right: 14, top: 10, bottom: 8, child: layer(0.6)),
        Padding(padding: const EdgeInsets.only(bottom: 16), child: card),
      ],
    );
  }
}

/// The overview card's faint background: concentric rings spreading from the
/// top-right corner and a soft glow in the bottom-left, all in low-opacity
/// white so the figures stay readable.
/// Opacity of an overview card ring at [t], its position from the innermost
/// ring (0) to the outermost (1): 0.24 down to 0.02.
@visibleForTesting
double ringOpacity(double t) => 0.24 - 0.22 * t.clamp(0.0, 1.0);

class _CardPattern extends CustomPainter {
  const _CardPattern();

  @override
  void paint(Canvas canvas, Size size) {
    // The innermost ring is the most visible; each ring further out fades a
    // step, down to almost nothing at the edge.
    final center = Offset(size.width * 0.92, size.height * 0.1);
    final maxRadius = size.width * 0.75;
    const firstRadius = 36.0, step = 26.0;
    for (var r = firstRadius; r <= maxRadius; r += step) {
      final t = (r - firstRadius) / (maxRadius - firstRadius);
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: ringOpacity(t)));
    }

    final glow = Paint()
      ..shader = RadialGradient(colors: [
        Colors.white.withValues(alpha: 0.12),
        Colors.white.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(
          center: Offset(0, size.height), radius: size.height * 0.9));
    canvas.drawCircle(Offset(0, size.height), size.height * 0.9, glow);
  }

  @override
  bool shouldRepaint(_CardPattern oldDelegate) => false;
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

/// One of the two side-by-side Your work cards: icon and count badge on top,
/// then the title and a one-line hint.
class _WorkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;
  const _WorkCard({
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconCircle(icon),
                  const Spacer(),
                  TintedBadge(label: badge, color: context.statusWarning),
                ],
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: OneHubTextStyles.bodyText(textPrimary)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: OneHubTextStyles.fieldLabel(textMuted)
                      .copyWith(letterSpacing: 0, fontSize: 11)),
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
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EarningsScreen())),
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
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
                    Text(dummyWalletBalance,
                        style: OneHubTextStyles.pageHeading(textPrimary)
                            .copyWith(fontSize: 22)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TintedBadge(
                      label: dummyPlan,
                      color: context.statusSuccess,
                      pill: true),
                  const SizedBox(height: 4),
                  Text(dummyRenewal,
                      style: OneHubTextStyles.fieldLabel(textMuted)
                          .copyWith(letterSpacing: 0, fontSize: 11)),
                ],
              ),
              const SizedBox(width: 8),
              Icon(OneHubIcons.chevronRight, size: 18, color: textMuted),
            ],
          ),
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
