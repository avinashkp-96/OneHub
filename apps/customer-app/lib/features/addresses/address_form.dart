import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';

/// What the customer has typed for one address, kept by the screen that
/// shows [AddressFields] (signup, or [AddressFormScreen]).
class AddressDraft {
  final house = TextEditingController();
  final street = TextEditingController();
  final landmark = TextEditingController();
  final pincode = TextEditingController();
  String label = 'Home';
  SavedLocation? location;

  /// The first thing missing or wrong, worded for the user; null when the
  /// address is complete.
  String? problem() {
    if (location == null) return 'Set the address on the map: use GPS or pick your area.';
    if (house.text.trim().isEmpty) return 'Enter the house or flat number.';
    if (street.text.trim().isEmpty) return 'Enter the street and area.';
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(pincode.text.trim())) {
      return 'Enter a 6-digit PIN code.';
    }
    return null;
  }

  JobAddress toAddress() => JobAddress(
        label: label,
        house: house.text.trim(),
        street: street.text.trim(),
        landmark: landmark.text.trim().isEmpty ? null : landmark.text.trim(),
        pincode: pincode.text.trim(),
        city: location!.city,
        latitude: location!.latitude,
        longitude: location!.longitude,
      );

  void dispose() {
    house.dispose();
    street.dispose();
    landmark.dispose();
    pincode.dispose();
  }
}

const addressLabels = ['Home', 'Office', 'Other'];

/// The address fields: an optional label choice, the map position (GPS or a
/// picked area, for distances), house or flat, street and area, landmark and
/// PIN code. Providers see the address only once the customer chooses them.
class AddressFields extends StatefulWidget {
  final AddressDraft draft;
  final bool showLabel;
  final bool enabled;

  /// Asks where the address is; tests pass one to skip the sheet and GPS.
  final LocationPicker? pickLocation;
  const AddressFields({
    super.key,
    required this.draft,
    this.showLabel = false,
    this.enabled = true,
    this.pickLocation,
  });

  @override
  State<AddressFields> createState() => _AddressFieldsState();
}

class _AddressFieldsState extends State<AddressFields> {
  Future<void> _pickLocation() async {
    final pick = widget.pickLocation ??
        (BuildContext context, SavedLocation? current) =>
            chooseLocation(context, api, current: current);
    final picked = await pick(context, widget.draft.location);
    if (picked != null && mounted) {
      setState(() => widget.draft.location = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final draft = widget.draft;
    const gap = SizedBox(height: OneHubTheme.sectionGap);
    const inner = SizedBox(height: OneHubTheme.gapFieldInternals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showLabel) ...[
          const FieldLabel('SAVE AS'),
          inner,
          Wrap(spacing: 8, children: [
            for (final l in addressLabels)
              ChoiceChip(
                key: Key('address-label-$l'),
                label: Text(l),
                selected: draft.label == l,
                onSelected: widget.enabled
                    ? (_) => setState(() => draft.label = l)
                    : null,
              ),
          ]),
          gap,
        ],
        const FieldLabel('MAP POSITION', required: true, icon: OneHubIcons.location),
        inner,
        Row(
          children: [
            OutlinedButton.icon(
              key: const Key('address-location'),
              onPressed: widget.enabled ? _pickLocation : null,
              icon: const Icon(OneHubIcons.location, size: 16),
              label: Text(draft.location == null ? 'Use GPS or pick area' : 'Change'),
            ),
            if (draft.location != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(draft.location!.city,
                    overflow: TextOverflow.ellipsis,
                    style: OneHubTextStyles.bodyText(textPrimary)
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        gap,
        const FieldLabel('HOUSE / FLAT NO. AND BUILDING', required: true, icon: OneHubIcons.home),
        inner,
        TextField(
          key: const Key('address-house'),
          controller: draft.house,
          enabled: widget.enabled,
          decoration: const InputDecoration(hintText: 'e.g. 12B, Palm Grove Apartments'),
        ),
        gap,
        const FieldLabel('STREET AND AREA', required: true),
        inner,
        TextField(
          key: const Key('address-street'),
          controller: draft.street,
          enabled: widget.enabled,
          decoration: const InputDecoration(hintText: 'e.g. Changampuzha Nagar, Edappally'),
        ),
        gap,
        const FieldLabel('LANDMARK (optional)'),
        inner,
        TextField(
          key: const Key('address-landmark'),
          controller: draft.landmark,
          enabled: widget.enabled,
          decoration: const InputDecoration(hintText: 'e.g. Near Edappally Church'),
        ),
        gap,
        const FieldLabel('PIN CODE', required: true),
        inner,
        TextField(
          key: const Key('address-pincode'),
          controller: draft.pincode,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: '6 digits', counterText: ''),
        ),
        const SizedBox(height: 6),
        Text('Only the provider you choose sees the full address.',
            style: OneHubTextStyles.fieldLabel(textSecondary)
                .copyWith(letterSpacing: 0, fontSize: 11)),
      ],
    );
  }
}

/// "Add address": the fields in a form card, saved through
/// POST /users/me/addresses. Pops with the saved [JobAddress].
class AddressFormScreen extends StatefulWidget {
  final LocationPicker? pickLocation;
  const AddressFormScreen({super.key, this.pickLocation});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _draft = AddressDraft();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = _draft.problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final json = await api.post('/users/me/addresses', _draft.toAddress().toJson(),
          auth: true);
      if (!mounted) return;
      Navigator.of(context).pop(JobAddress.tryParse(json));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save the address: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Add address')),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Where providers should come for the job.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(_error!,
                              style: TextStyle(color: context.statusDanger)),
                        ),
                      AddressFields(
                          draft: _draft,
                          showLabel: true,
                          enabled: !_saving,
                          pickLocation: widget.pickLocation),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      PrimaryCta(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? 'Saving…' : 'Save address')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
