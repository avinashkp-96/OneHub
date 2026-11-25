import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';
import '../addresses/address_form.dart';
import '../addresses/addresses_screen.dart';
import '../profile/profile_state.dart';

// docx 4.3 — Post a Requirement. `subServiceId` is carried over from category
// browsing (docx 4.1 "Service Categories" -> sub-service list), which isn't
// built yet, so this screen currently requires it to be passed in directly.
// Restyled to match the current OneHub design system (no new reference —
// applied on request, using existing tokens/components and general UX
// principles): a GlowCard for the primary form fields (the single "form
// card" per screen, per the standing pattern), a separate section for
// provider selection since that's a repeated list, not more form-card
// content, and a page title in the AppBar matching the auth
// screens' OTP step, rather than an AppBar title plus a second heading.
//
// Photos: up to [maxRequestPhotos], each uploaded as soon as it is picked
// (POST /uploads/photo) so sending only carries their links. Providers see
// them on the request before they send a price.
const maxRequestPhotos = 5;

class PostRequirementScreen extends StatefulWidget {
  final String subServiceId;

  /// Asks for a photo; tests pass a fake. Defaults to the camera or gallery.
  final PhotoPicker pickPhoto;

  /// Passed on to Add address; tests use it to skip the sheet and GPS.
  final LocationPicker? pickLocation;

  /// A provider to tick from the start (the one tapped in search or Nearby
  /// providers), if they are in the list for this job.
  final String? preselectedProviderId;
  const PostRequirementScreen(
      {super.key,
      required this.subServiceId,
      this.pickPhoto = choosePhoto,
      this.pickLocation,
      this.preselectedProviderId});

  @override
  State<PostRequirementScreen> createState() => _PostRequirementScreenState();
}

class _PostRequirementScreenState extends State<PostRequirementScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime? _preferredAt;
  List<ProviderSummary> _providers = [];
  final Set<String> _selectedProviderIds = {};
  bool _loading = true;
  bool _sending = false;
  // A send that failed for no field's reason (no connection, a server
  // fault), shown just above Send Request.
  String? _error;
  // Why the provider list could not load, shown in that section.
  String? _providersError;
  // Problems shown at their own field: title, description, photos, address,
  // providers.
  final Map<String, String> _fieldErrors = {};

  void _clear(String field) {
    if (_fieldErrors.remove(field) != null) setState(() {});
  }
  final List<String> _photoUrls = [];
  int _uploading = 0;

  // The job address: one of the customer's saved addresses, the first by
  // default. Providers are measured from it.
  List<JobAddress>? _addresses;
  JobAddress? _address;

  Future<void> _loadAddresses() async {
    try {
      final list = await loadAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = list;
        _address ??= list.isEmpty ? null : list.first;
      });
    } catch (_) {
      if (mounted) setState(() => _addresses = const []);
    }
  }

  void _chooseAddress(JobAddress a) {
    if (a.id == _address?.id) return;
    setState(() {
      _address = a;
      _loading = true;
      _providersError = null;
      _selectedProviderIds.clear();
    });
    _loadProviders();
  }

  Future<void> _addAddress() async {
    final added = await Navigator.of(context).push<JobAddress>(MaterialPageRoute(
        builder: (_) => AddressFormScreen(pickLocation: widget.pickLocation)));
    if (added == null || !mounted) return;
    setState(() => _addresses = [...?_addresses, added]);
    _chooseAddress(added);
  }

  Future<void> _addPhoto() async {
    final photo = await widget.pickPhoto(context);
    if (photo == null || !mounted) return;
    setState(() {
      _uploading++;
      _fieldErrors.remove('photos');
    });
    try {
      final url = await api.upload('/uploads/photo', photo.bytes, photo.name);
      if (mounted) setState(() => _photoUrls.add(url));
    } catch (e) {
      if (mounted) {
        setState(() => _fieldErrors['photos'] =
            'Could not add the photo. ${userMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _uploading--);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAddresses().then((_) => _loadProviders());
  }

  Future<void> _loadProviders() async {
    try {
      // With a position the API lists providers nearest first and leaves
      // out those whose coverage does not reach the job: the job address,
      // else the location saved from Home.
      final address = _address;
      final near = address == null
          ? customerLocation.value
          : SavedLocation(
              city: address.city,
              latitude: address.latitude,
              longitude: address.longitude);
      final json = await api.get(
              '/providers?subServiceId=${widget.subServiceId}${near == null ? '' : '&${near.query}'}')
          as List;
      if (!mounted) return;
      setState(() {
        _providers = json
            .map((p) => ProviderSummary.fromJson(p as Map<String, dynamic>))
            .toList();
        final wanted = widget.preselectedProviderId;
        if (wanted != null && _providers.any((p) => p.id == wanted)) {
          _selectedProviderIds.add(wanted);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _providersError = 'Could not load providers. ${userMessage(e)}';
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
    final problems = {
      if (_title.text.trim().isEmpty) 'title': 'Add a title.',
      if (_description.text.trim().isEmpty)
        'description': 'Describe the work you need done.',
      if (_address == null) 'address': 'Add the address for this job.',
      if (_selectedProviderIds.isEmpty)
        'providers': 'Select at least one provider.',
    };
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(problems);
      _error = null;
    });
    if (problems.isNotEmpty) return;
    setState(() => _sending = true);
    try {
      await api.post(
          '/requirements',
          {
            'subServiceId': widget.subServiceId,
            'addressId': _address!.id,
            'title': _title.text.trim(),
            'description': _description.text.trim(),
            if (_preferredAt != null)
              'preferredAt': _preferredAt!.toIso8601String(),
            'providerIds': _selectedProviderIds.toList(),
            if (_photoUrls.isNotEmpty) 'photoUrls': _photoUrls,
          },
          auth: true);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final bar = successSnackBar(
            context, 'Request sent. Providers will reply with their prices.');
        // Back to a fresh Home tab, which reloads Active requests so the new
        // one shows. Clearing the stack keeps Back from reopening the
        // category, service list or this sent form.
        Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(bar);
      }
    } catch (e) {
      final field = errorField(e, const {
        'title': ['title'],
        'description': ['description'],
        'photos': ['photo'],
        'address': ['address'],
        'providers': ['provider'],
      });
      setState(() {
        if (field != null) {
          _fieldErrors[field] = userMessage(e);
        } else {
          _error = 'Could not send the request. ${userMessage(e)}';
        }
      });
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
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Tell us what you need')),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: OneHubTheme.pageMargin, vertical: 8),
              children: [
                Text(
                  'Describe the job and pick who should hear about it.',
                  style: OneHubTextStyles.bodyText(textSecondary),
                ),
                const SizedBox(height: OneHubTheme.sectionGap),
                GlowCard(
                  child: Padding(
                    padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FieldLabel('TITLE',
                            required: true, icon: OneHubIcons.edit),
                        const SizedBox(height: OneHubTheme.gapFieldInternals),
                        TextField(
                          key: const Key('request-title'),
                          controller: _title,
                          maxLength: requestTitleMaxLength,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => _clear('title'),
                          decoration: InputDecoration(
                              hintText: 'e.g. Ceiling fan repair',
                              errorText: _fieldErrors['title']),
                        ),
                        const SizedBox(height: OneHubTheme.gapFieldInternals),
                        const FieldLabel('WHAT DO YOU NEED DONE?',
                            required: true, icon: OneHubIcons.documentList),
                        const SizedBox(height: OneHubTheme.gapFieldInternals),
                        TextField(
                          key: const Key('request-description'),
                          controller: _description,
                          maxLines: 4,
                          onChanged: (_) => _clear('description'),
                          decoration: InputDecoration(
                              hintText:
                                  'e.g. The fan makes a rattling noise at high speed',
                              errorText: _fieldErrors['description']),
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
                        const SizedBox(height: OneHubTheme.sectionGap),
                        const FieldLabel('PHOTOS (OPTIONAL)',
                            icon: OneHubIcons.image),
                        const SizedBox(height: OneHubTheme.gapFieldInternals),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < _photoUrls.length; i++)
                              _RemovablePhoto(
                                key: Key('request-photo-$i'),
                                url: api.resolve(_photoUrls[i]),
                                onRemove: () =>
                                    setState(() => _photoUrls.removeAt(i)),
                              ),
                            for (var i = 0; i < _uploading; i++)
                              const _PhotoSlot(
                                  child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))),
                            if (_photoUrls.length + _uploading <
                                maxRequestPhotos)
                              _PhotoSlot(
                                key: const Key('add-photo'),
                                onTap: _addPhoto,
                                child: Icon(OneHubIcons.camera,
                                    size: 22, color: textMuted),
                              ),
                          ],
                        ),
                        FieldError(_fieldErrors['photos']),
                        const SizedBox(height: 6),
                        Text(
                            'Up to $maxRequestPhotos. Providers see them before they send a price.',
                            style: OneHubTextStyles.fieldLabel(textMuted)
                                .copyWith(letterSpacing: 0, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text('Job address',
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  'Only the provider you choose sees the full address.',
                  style: OneHubTextStyles.fieldLabel(textMuted)
                      .copyWith(letterSpacing: 0),
                ),
                const SizedBox(height: 12),
                if (_addresses == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  for (final a in _addresses!)
                    AddressCard(
                      key: Key('address-${a.id}'),
                      address: a,
                      selected: a.id == _address?.id,
                      onTap: () => _chooseAddress(a),
                    ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('add-address'),
                    onPressed: _addAddress,
                    icon: const Icon(OneHubIcons.plus, size: 16),
                    label: const Text('Add address'),
                  ),
                ),
                FieldError(_fieldErrors['address']),
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
                const SizedBox(height: 2),
                Text(
                  switch ((_address?.city, customerLocation.value)) {
                    (final String city, _) => 'Nearest first, from $city.',
                    (null, final SavedLocation l) =>
                      'Nearest first, from ${l.city}.',
                    (null, null) =>
                      'Add the job address to see the nearest first.',
                  },
                  key: const Key('providers-near'),
                  style: OneHubTextStyles.fieldLabel(textMuted)
                      .copyWith(letterSpacing: 0),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_providersError != null)
                  Text(_providersError!,
                      style: TextStyle(color: context.statusDanger))
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
                        if (!_selectedProviderIds.remove(p.id)) {
                          _selectedProviderIds.add(p.id);
                        }
                        _fieldErrors.remove('providers');
                      }),
                    ),
                FieldError(_fieldErrors['providers']),
                const SizedBox(height: 20),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        style: TextStyle(color: context.statusDanger)),
                  ),
                PrimaryCta(
                  onPressed:
                      _sending || _uploading > 0 ? null : _sendRequest,
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

/// A 72px input-styled slot for the add button or an upload in progress.
class _PhotoSlot extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PhotoSlot({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? OneHubColors.inputFillDark : OneHubColors.inputFillLight;
    final border =
        dark ? OneHubColors.inputBorderDark : OneHubColors.inputBorderLight;
    final radius = BorderRadius.circular(OneHubTheme.radiusInputField);
    return InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: fill, borderRadius: radius, border: Border.all(color: border)),
        child: child,
      ),
    );
  }
}

/// An uploaded photo with a small remove button in its corner.
class _RemovablePhoto extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;
  const _RemovablePhoto({super.key, required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PhotoThumb(url: url),
        Positioned(
          top: -6,
          right: -6,
          child: Semantics(
            button: true,
            label: 'Remove photo',
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: context.statusDanger),
                child: const Icon(OneHubIcons.delete,
                    size: 13, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
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
                        if (provider.distanceKm != null) ...[
                          const SizedBox(width: 8),
                          Text(distanceLabel(provider.distanceKm!),
                              style: OneHubTextStyles.fieldLabel(textMuted)
                                  .copyWith(letterSpacing: 0, fontSize: 12)),
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
