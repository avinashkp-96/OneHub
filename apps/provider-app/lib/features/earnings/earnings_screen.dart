import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';

// Provider earnings and wallet, opened from the wallet card on the
// dashboard. Matches the other provider screens (PageGlow, back-only AppBar
// plus in-body heading, one GlowCard, bordered cards) — no new reference,
// applied on request.
//
// Every figure here is explicit dummy data: there is no earnings, wallet or
// billing endpoint yet. The four `dummy*` values the dashboard also shows are
// defined here once, so its wallet card and summary can't disagree with this
// screen. Replace all of it when those endpoints exist.
const dummyEarnedToday = '₹1,850';
const dummyWalletBalance = '₹1,250';
const dummyPlan = 'PRO PLAN';
const dummyRenewal = 'Renews 12 Nov';

const _dummyEarnedWeek = '₹6,420';
const _dummyEarnedMonth = '₹21,300';

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

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Earnings',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 26)),
              const SizedBox(height: 8),
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
                          TintedBadge(
                              label: dummyPlan,
                              color: context.statusSuccess,
                              pill: true),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(dummyWalletBalance,
                          style: OneHubTextStyles.pageHeading(textPrimary)
                              .copyWith(fontSize: 34)),
                      const SizedBox(height: 6),
                      Text(dummyRenewal,
                          style: OneHubTextStyles.fieldLabel(textMuted)
                              .copyWith(letterSpacing: 0, fontSize: 12)),
                    ],
                  ),
                ),
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
                          label: 'THIS MONTH', value: _dummyEarnedMonth),
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
