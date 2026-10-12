import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';

// docx 5.5 "Plan Management Screen": see the current plan and switch between
// pay-per-service and the two monthly plans. Same shell as the other provider
// screens (PageGlow, back-only AppBar plus in-body heading, one GlowCard,
// bordered cards).
//
// This one talks to the real endpoints: GET /users/me for the provider's own
// id, then GET and PUT /providers/:id/subscription. There is no payment
// gateway yet (see CLAUDE.md, Integrations), so switching a plan changes the
// record without charging anything, and the screen says so.
//
// Plan names, prices and included unlocks mirror PLAN_LIMITS in the API's
// SubscriptionsService; keep the two in step.
class PlanOption {
  final String key; // the API's plan enum value
  final String name;
  final String price;
  final String detail;
  final int includedUnlocks;
  const PlanOption(
      this.key, this.name, this.price, this.detail, this.includedUnlocks);
}

const planOptions = [
  PlanOption('PER_SERVICE', 'Pay per service', '₹50 per unlock',
      'Pay only when you unlock a customer\'s contact.', 0),
  PlanOption('MONTHLY_99', 'Monthly 99', '₹99 a month',
      '5 contact unlocks included each month.', 5),
  PlanOption('MONTHLY_299', 'Monthly 299', '₹299 a month',
      '10 contact unlocks included each month.', 10),
];

/// Takes an optional [client], like the other provider screens, so tests can
/// use a fake API.
class PlansScreen extends StatefulWidget {
  final ApiClient? client;
  const PlansScreen({super.key, this.client});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  ApiClient get _api => widget.client ?? api;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _providerId;
  String _currentKey = 'PER_SERVICE';
  int _used = 0;
  String _selectedKey = 'PER_SERVICE';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await _api.get('/users/me') as Map<String, dynamic>;
      final provider = me['provider'] as Map<String, dynamic>?;
      if (provider == null) {
        throw 'this account has no provider profile';
      }
      final providerId = provider['id'] as String;
      final sub = await _api.get('/providers/$providerId/subscription');
      if (!mounted) return;
      setState(() {
        _providerId = providerId;
        if (sub is Map<String, dynamic>) {
          _currentKey = sub['plan'] as String;
          _used = (sub['cycleUsed'] as num?)?.toInt() ?? 0;
        }
        _selectedKey = _currentKey;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your plan: $e';
        _loading = false;
      });
    }
  }

  Future<void> _switch() async {
    final target = planOptions.firstWhere((p) => p.key == _selectedKey);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Switch to ${target.name}?'),
        content: const Text(
            'Your monthly usage starts again from zero on the new plan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Switch')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.put(
          '/providers/$_providerId/subscription', {'plan': target.key},
          auth: true);
      if (!mounted) return;
      setState(() {
        _currentKey = target.key;
        _used = 0;
      });
      showSuccessMessage(context, 'Plan changed to ${target.name}.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not change your plan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final border =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final current = planOptions.firstWhere((p) => p.key == _currentKey);
    final changed = _selectedKey != _currentKey;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Plans',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text('Choose how you pay to unlock customer contacts.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!,
                      style: TextStyle(color: context.statusDanger)),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_providerId != null) ...[
                GlowCard(
                  child: Padding(
                    padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('CURRENT PLAN',
                                  style:
                                      OneHubTextStyles.fieldLabel(textMuted)),
                            ),
                            TintedBadge(
                                label: 'ACTIVE',
                                color: context.statusSuccess,
                                pill: true),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(current.name,
                            style: OneHubTextStyles.pageHeading(textPrimary)
                                .copyWith(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(current.price,
                            style: OneHubTextStyles.bodyText(textSecondary)),
                        if (current.includedUnlocks > 0) ...[
                          const SizedBox(height: 16),
                          Text(
                              '$_used of ${current.includedUnlocks} unlocks used this month',
                              style: OneHubTextStyles.bodyText(textPrimary)
                                  .copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              key: const Key('plan-usage'),
                              minHeight: 8,
                              value: (_used / current.includedUnlocks)
                                  .clamp(0.0, 1.0),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text('All plans',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 18)),
                const SizedBox(height: 12),
                for (final plan in planOptions)
                  _PlanTile(
                    plan: plan,
                    selected: plan.key == _selectedKey,
                    isCurrent: plan.key == _currentKey,
                    borderColor: border,
                    onTap: _saving
                        ? null
                        : () => setState(() => _selectedKey = plan.key),
                  ),
                const SizedBox(height: 12),
                PrimaryCta(
                  onPressed: (!changed || _saving) ? null : _switch,
                  child: Text(_saving ? 'Switching…' : 'Switch plan'),
                ),
                const SizedBox(height: 12),
                Text(
                    'Payments are not set up yet, so switching charges nothing.',
                    textAlign: TextAlign.center,
                    style: OneHubTextStyles.fieldLabel(textMuted)
                        .copyWith(letterSpacing: 0, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final PlanOption plan;
  final bool selected;
  final bool isCurrent;
  final Color borderColor;
  final VoidCallback? onTap;
  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.isCurrent,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        side: BorderSide(
            color: selected ? OneHubColors.primary : borderColor,
            width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? OneHubColors.primary : Colors.transparent,
                  border: Border.all(
                      color: selected ? OneHubColors.primary : borderColor,
                      width: 2),
                ),
                child: selected
                    ? const Icon(OneHubIcons.successCheck,
                        size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(plan.name,
                              style: OneHubTextStyles.bodyText(textPrimary)
                                  .copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                        ),
                        if (isCurrent)
                          TintedBadge(
                              label: 'CURRENT',
                              color: context.statusSuccess,
                              pill: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(plan.price,
                        style: OneHubTextStyles.bodyText(OneHubColors.primary)
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(plan.detail,
                        style: OneHubTextStyles.bodyText(textSecondary)
                            .copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
