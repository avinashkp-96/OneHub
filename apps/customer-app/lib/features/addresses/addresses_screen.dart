import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import 'address_form.dart';

/// The customer's saved addresses, oldest first.
Future<List<JobAddress>> loadAddresses() async {
  final json = await api.get('/users/me/addresses') as List;
  return json.map(JobAddress.tryParse).whereType<JobAddress>().toList();
}

/// One saved address as a bordered card: the label as a badge and the
/// address on one line. [selected] gives it the primary border (the request
/// form's choice); [trailing] goes on the right (Saved addresses' delete).
class AddressCard extends StatelessWidget {
  final JobAddress address;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  const AddressCard(
      {super.key,
      required this.address,
      this.selected = false,
      this.onTap,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final cardBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final radius = BorderRadius.circular(OneHubTheme.radiusFormCard);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: selected ? OneHubColors.primary : cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(selected ? OneHubIcons.confirmed : OneHubIcons.location,
                  size: 20,
                  color: selected ? OneHubColors.primary : textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TintedBadge(
                        label: address.label.toUpperCase(),
                        color: OneHubColors.primary),
                    const SizedBox(height: 6),
                    Text(address.oneLine,
                        style: OneHubTextStyles.bodyText(textSecondary)
                            .copyWith(fontSize: 13)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile > Saved addresses: the list, Add address, and delete (the last one
/// stays, since a request needs one). Requests keep their own copy, so a
/// removed address never changes a job already sent.
class AddressesScreen extends StatefulWidget {
  final LocationPicker? pickLocation;
  const AddressesScreen({super.key, this.pickLocation});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<JobAddress>? _addresses;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await loadAddresses();
      if (mounted) setState(() => _addresses = list);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load your addresses. ${userMessage(e)}');
    }
  }

  Future<void> _add() async {
    final added = await Navigator.of(context).push<JobAddress>(MaterialPageRoute(
        builder: (_) => AddressFormScreen(pickLocation: widget.pickLocation)));
    if (added == null || !mounted) return;
    showSuccessMessage(context, 'Address saved.');
    await _load();
  }

  Future<void> _delete(JobAddress address) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this address?'),
        content: Text(address.oneLine),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    try {
      await api.delete('/users/me/addresses/${address.id}');
      if (!mounted) return;
      showSuccessMessage(context, 'Address deleted.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            SnackBar(content: Text('Could not delete it. ${userMessage(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final addresses = _addresses;
    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Saved addresses')),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Where providers come for your jobs.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              if (_error != null)
                Text(_error!, style: TextStyle(color: context.statusDanger))
              else if (addresses == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final a in addresses)
                  AddressCard(
                    key: Key('saved-address-${a.id}'),
                    address: a,
                    trailing: IconButton(
                      tooltip: 'Delete address',
                      icon: const Icon(OneHubIcons.delete, size: 18),
                      onPressed: () => _delete(a),
                    ),
                  ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('add-address'),
                onPressed: _add,
                icon: const Icon(OneHubIcons.plus, size: 16),
                label: const Text('Add address'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Home chip's sheet: the customer's saved addresses and "Add new
/// address", which opens [AddressFormScreen]. Returns the chosen (or newly
/// added) address as the position to measure providers from; null when the
/// customer backs out. [current] marks the address Home is set to.
Future<SavedLocation?> chooseHomeAddress(
    BuildContext context, SavedLocation? current) async {
  final picked = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _HomeAddressSheet(current: current),
  );
  JobAddress? address;
  if (picked == _addNew) {
    if (!context.mounted) return null;
    address = await Navigator.of(context).push<JobAddress>(
        MaterialPageRoute(builder: (_) => const AddressFormScreen()));
  } else if (picked is JobAddress) {
    address = picked;
  }
  if (address == null) return null;
  return SavedLocation(
      city: address.city,
      latitude: address.latitude,
      longitude: address.longitude);
}

const _addNew = 'add-new-address';

class _HomeAddressSheet extends StatefulWidget {
  final SavedLocation? current;
  const _HomeAddressSheet({this.current});

  @override
  State<_HomeAddressSheet> createState() => _HomeAddressSheetState();
}

class _HomeAddressSheetState extends State<_HomeAddressSheet> {
  List<JobAddress>? _addresses;
  String? _error;

  @override
  void initState() {
    super.initState();
    loadAddresses().then((list) {
      if (mounted) setState(() => _addresses = list);
    }).catchError((Object _) {
      if (mounted) setState(() => _error = 'Could not load your addresses.');
    });
  }

  bool _isCurrent(JobAddress a) =>
      widget.current != null &&
      a.latitude == widget.current!.latitude &&
      a.longitude == widget.current!.longitude;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final addresses = _addresses;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Choose an address',
                  style: OneHubTextStyles.topBarTitle(textPrimary)),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(_error!,
                    style: OneHubTextStyles.bodyText(context.statusDanger)),
              )
            else if (addresses == null)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final a in addresses)
                ListTile(
                  key: Key('home-address-${a.id}'),
                  leading: const Icon(OneHubIcons.location,
                      color: OneHubColors.primary),
                  title: Text(a.label),
                  subtitle: Text(a.oneLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: OneHubTextStyles.bodyText(textSecondary)
                          .copyWith(fontSize: 13)),
                  trailing: _isCurrent(a)
                      ? const Icon(OneHubIcons.successCheck,
                          size: 18, color: OneHubColors.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(a),
                ),
            ListTile(
              key: const Key('home-add-address'),
              leading: const Icon(OneHubIcons.plus, color: OneHubColors.primary),
              title: const Text('Add new address'),
              onTap: () => Navigator.of(context).pop(_addNew),
            ),
          ],
        ),
      ),
    );
  }
}
