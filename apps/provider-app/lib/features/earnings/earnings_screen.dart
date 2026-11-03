import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../plans/plans_screen.dart';

// Provider earnings and wallet, opened from the wallet card on the
// dashboard. Matches the other provider screens (PageGlow, page title in the AppBar, one GlowCard, bordered cards) — no new reference,
// applied on request.
//
// The plan pill and renewal line are real (GET /providers/me, then
// /providers/:id/subscription, as on the dashboard wallet card). Every other
// figure is explicit dummy data: there is no earnings, wallet or billing
// endpoint yet. The `dummy*` values the dashboard also shows are defined here
// once, so its wallet card and summary can't disagree with this screen.
// Replace all of it when those endpoints exist.
const dummyEarnedToday = '₹1,850';
const dummyWalletBalance = '₹1,250';

const _dummyEarnedWeek = '₹6,420';
const dummyEarnedMonth = '₹21,300';

class _Transaction {
  final String title;
  final String detail;
  final String when;
  final String amount;
  final bool credit;
  const _Transaction(this.title, this.detail, this.when, this.amount,
      {required this.credit});
}

const _dummyTransactions = [
  _Transaction(
      'Job completed', 'Install two ceiling lights', 'Today', '+₹1,200',
      credit: true),
  _Transaction(
      'Contact unlock fee', 'Fuse box replacement', 'Yesterday', '−₹50',
      credit: false),
  _Transaction('Job completed', 'Fuse box replacement', 'Yesterday', '+₹650',
      credit: true),
  _Transaction('Pro plan', 'Monthly subscription', '12 Oct', '−₹499',
      credit: false),
];

/// Takes an optional [client], like the other provider screens, so tests can
/// use a fake API.
class EarningsScreen extends StatefulWidget {
  final ApiClient? client;
  const EarningsScreen({super.key, this.client});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  ApiClient get _api => widget.client ?? api;

  // Null until it loads, and if it fails: the pill and renewal line hide.
  CurrentPlan? _plan;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    try {
      final me = await _api.get('/providers/me') as Map<String, dynamic>;
      final plan = await loadCurrentPlan(_api, me['id'] as String);
      if (!mounted) return;
      setState(() => _plan = plan);
    } catch (_) {
      // Manage plan below opens the Plans screen, which shows the error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final renewal = plan?.renewalLabel;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final divider =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Earnings')),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Your wallet and what you have earned.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text('WALLET BALANCE',
                                  style:
                                      OneHubTextStyles.fieldLabel(textMuted))),
                          if (plan != null)
                            TintedBadge(
                                label: plan.badgeLabel,
                                color: context.statusSuccess,
                                pill: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(dummyWalletBalance,
                          style: OneHubTextStyles.pageHeading(textPrimary)
                              .copyWith(fontSize: 34)),
                      if (renewal != null) ...[
                        const SizedBox(height: 6),
                        Text(renewal,
                            style: OneHubTextStyles.fieldLabel(textMuted)
                                .copyWith(letterSpacing: 0, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OneHubLinkTile(
                icon: OneHubIcons.wallet,
                title: 'Manage plan',
                subtitle: 'Switch between pay per unlock and monthly',
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => PlansScreen(client: widget.client)))
                    .then((_) => mounted ? _loadPlan() : null),
              ),
              const SizedBox(height: 26),
              Text('Earned',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      const _EarnedRow(label: 'TODAY', value: dummyEarnedToday),
                      Divider(height: 1, color: divider),
                      const _EarnedRow(
                          label: 'THIS WEEK', value: _dummyEarnedWeek),
                      Divider(height: 1, color: divider),
                      const _EarnedRow(
                          label: 'THIS MONTH', value: dummyEarnedMonth),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text('Recent activity',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              for (final t in _dummyTransactions)
                _TransactionTile(transaction: t),
              const SizedBox(height: 8),
              Text(
                "Payouts and card payments aren't set up yet.",
                textAlign: TextAlign.center,
                style: OneHubTextStyles.fieldLabel(textMuted)
                    .copyWith(letterSpacing: 0, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarnedRow extends StatelessWidget {
  final String label;
  final String value;
  const _EarnedRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
              child:
                  Text(label, style: OneHubTextStyles.fieldLabel(textMuted))),
          Text(value,
              style: OneHubTextStyles.bodyText(textPrimary)
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final _Transaction transaction;
  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final iconFill =
        dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final border =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final color =
        transaction.credit ? context.statusSuccess : context.statusDanger;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconFill,
                  border: Border.all(color: border)),
              child: Icon(
                  transaction.credit
                      ? OneHubIcons.successCheck
                      : OneHubIcons.wallet,
                  size: 18,
                  color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.title,
                      style: OneHubTextStyles.bodyText(textPrimary)
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${transaction.detail} · ${transaction.when}',
                      style: OneHubTextStyles.fieldLabel(textMuted)
                          .copyWith(letterSpacing: 0, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(transaction.amount,
                style: OneHubTextStyles.bodyText(color)
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
