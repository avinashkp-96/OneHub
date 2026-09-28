import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';

// docx 4.3 — Post a Requirement. `subServiceId` is carried over from category
// browsing (docx 4.1 "Service Categories" -> sub-service list), which isn't
// built yet, so this screen currently requires it to be passed in directly.
// Restyled to match the current OneHub design system (no new reference —
// applied on request, using existing tokens/components and general UX
// principles): a GlowCard for the primary form fields (the single "form
// card" per screen, per the standing pattern), a separate section for
// provider selection since that's a repeated list, not more form-card
// content, and a back-only AppBar + in-body heading matching the auth
// screens' OTP step, rather than an AppBar title plus a second heading.
class PostRequirementScreen extends StatefulWidget {
  final String subServiceId;
  const PostRequirementScreen({super.key, required this.subServiceId});

  @override
  State<PostRequirementScreen> createState() => _PostRequirementScreenState();
}

class _PostRequirementScreenState extends State<PostRequirementScreen> {
  final _description = TextEditingController();
  DateTime? _preferredAt;
  List<ProviderSummary> _providers = [];
  final Set<String> _selectedProviderIds = {};
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final json = await api
          .get('/providers?subServiceId=${widget.subServiceId}') as List;
      if (!mounted) return;
      setState(() {
        _providers = json
            .map((p) => ProviderSummary.fromJson(p as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load providers: $e';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDate: _preferredAt ?? DateTime.now(),
    );
    if (picked != null) setState(() => _preferredAt = picked);
  }

  Future<void> _sendRequest() async {
    if (_description.text.trim().isEmpty || _selectedProviderIds.isEmpty) {
      setState(
          () => _error = 'Describe the work and select at least one provider.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await api.post(
          '/requirements',
          {
            'subServiceId': widget.subServiceId,
            'description': _description.text.trim(),
            if (_preferredAt != null)
              'preferredAt': _preferredAt!.toIso8601String(),
            'providerIds': _selectedProviderIds.toList(),
          },
          auth: true);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Could not send the request: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
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
    final inputFill =
        dark ? OneHubColors.inputFillDark : OneHubColors.inputFillLight;
    final inputBorder =
        dark ? OneHubColors.inputBorderDark : OneHubColors.inputBorderLight;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: OneHubTheme.pageMargin, vertical: 8),
              children: [
                Text('Tell us what you need',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 26)),
                const SizedBox(height: 8),
                Text(
                  'Describe the job and pick who should hear about it.',
                  style: OneHubTextStyles.bodyText(textSecondary),
                ),
                const SizedBox(height: OneHubTheme.sectionGap),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!,
                        style: TextStyle(color: context.statusDanger)),
                  ),
                GlowCard(
                  child: Padding(
                    padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FieldLabel('WHAT DO YOU NEED DONE?',
                            required: true, icon: OneHubIcons.edit),
                        const SizedBox(height: OneHubTheme.gapFieldInternals),
                        TextField(
                          controller: _description,
                          maxLines: 4,
                          decoration: const InputDecoration(
                              hintText:
                                  'e.g. Ceiling fan making a rattling noise'),
                        ),
                        const SizedBox(height: OneHubTheme.sectionGap),
                        const FieldLabel('PREFERRED DATE/TIME (OPTIONAL)',
                            icon: OneHubIcons.calendar),
                        const SizedBox(height: OneHubTheme.gapFieldInternals),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(
                              OneHubTheme.radiusInputField),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: OneHubTheme.fieldPaddingX,
                                vertical: 14),
                            decoration: BoxDecoration(
                              color: inputFill,
                              borderRadius: BorderRadius.circular(
                                  OneHubTheme.radiusInputField),
                              border: Border.all(color: inputBorder),
                            ),
                            child: Text(
                              _preferredAt == null
                                  ? 'Any time works'
                                  : _formatDate(_preferredAt!),
                              style: OneHubTextStyles.bodyText(
                                  _preferredAt == null
                                      ? textMuted
                                      : textPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text('Select providers',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  'Only the providers you pick will see this request.',
                  style: OneHubTextStyles.fieldLabel(textMuted)
                      .copyWith(letterSpacing: 0),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_providers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No providers found nearby. Try widening your search.',
                      style: OneHubTextStyles.bodyText(context.statusWarning),
                    ),
                  )
                else
                  for (final p in _providers)
                    _ProviderTile(
                      provider: p,
                      selected: _selectedProviderIds.contains(p.id),
                      onTap: () => setState(() {
                        if (!_selectedProviderIds.remove(p.id))
                          _selectedProviderIds.add(p.id);
                      }),
                    ),
                const SizedBox(height: 20),
                PrimaryCta(
                  onPressed: _sending ? null : _sendRequest,
                  child: _sending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Send Request'),
                ),
              ]),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _ProviderTile extends StatelessWidget {
  final ProviderSummary provider;
  final bool selected;
  final VoidCallback onTap;
  const _ProviderTile(
      {required this.provider, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final cardBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        side: BorderSide(color: selected ? OneHubColors.primary : cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                selected ? OneHubIcons.confirmed : OneHubIcons.plus,
                color: selected ? OneHubColors.primary : textMuted,
                size: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provider.name,
                        style: OneHubTextStyles.bodyText(textPrimary)
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TintedBadge(
                          label:
                              '${provider.averageRating.toStringAsFixed(1)} ★',
                          color: context.statusWarning,
                        ),
                        if (provider.certified) ...[
                          const SizedBox(width: 6),
                          const TintedBadge(
                              label: 'CERTIFIED', color: OneHubColors.success),
                        ],
                      ],
                    ),
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
