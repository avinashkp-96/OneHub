import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../requirements/post_requirement_screen.dart';

// docx 4.1 "tap to browse sub-services" -> 4.3 "Category / Sub-service" field,
// pre-filled from here when the customer taps through to post a requirement.
// Restyled to match the current OneHub design system (no new reference —
// applied on request): PageGlow behind the page, a back-only AppBar plus an
// in-body heading (the category name), and sub-service rows as bordered
// cards with a price-range TintedBadge and a trailing chevron, matching the
// tile pattern used for provider/bid rows elsewhere in this feature.
class SubServiceListScreen extends StatefulWidget {
  final ServiceCategory category;
  const SubServiceListScreen({super.key, required this.category});

  @override
  State<SubServiceListScreen> createState() => _SubServiceListScreenState();
}

class _SubServiceListScreenState extends State<SubServiceListScreen> {
  List<SubService> _subServices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await api
          .get('/categories/${widget.category.id}/sub-services') as List;
      if (!mounted) return;
      setState(() {
        _subServices = json
            .map((s) => SubService.fromJson(s as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load services: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: OneHubTheme.pageMargin, vertical: 8),
              children: [
                Text(widget.category.name,
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 26)),
                const SizedBox(height: 8),
                Text(
                  'Pick a service to describe your job.',
                  style: OneHubTextStyles.bodyText(textSecondary),
                ),
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
                else if (_subServices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No services listed under this category yet.',
                      style: OneHubTextStyles.bodyText(context.statusWarning),
                    ),
                  )
                else
                  for (final s in _subServices)
                    _SubServiceTile(
                      subService: s,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                PostRequirementScreen(subServiceId: s.id)),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubServiceTile extends StatelessWidget {
  final SubService subService;
  final VoidCallback onTap;
  const _SubServiceTile({required this.subService, required this.onTap});

  String? get _priceRangeLabel {
    if (subService.suggestedMinPrice == null ||
        subService.suggestedMaxPrice == null) return null;
    return '₹${subService.suggestedMinPrice!.toStringAsFixed(0)}–₹${subService.suggestedMaxPrice!.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final priceLabel = _priceRangeLabel;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(subService.name,
                        style: OneHubTextStyles.bodyText(textPrimary)
                            .copyWith(fontWeight: FontWeight.w600)),
                    if (priceLabel != null) ...[
                      const SizedBox(height: 6),
                      TintedBadge(
                          label: 'TYPICALLY $priceLabel',
                          color: OneHubColors.primary),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(OneHubIcons.chevronRight, size: 18, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
