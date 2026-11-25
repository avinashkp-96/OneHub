import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';
import '../business/business_details.dart';

// docx 5.2: the rest of the provider profile. Profile photo, ID proof and the
// bank or UPI details payouts go to. Reached from the "Payout & documents"
// tile on Profile. Same shell as the other provider screens (PageGlow, page
// title in the AppBar, one GlowCard).
//
// The photo and the ID proof are picked from the camera or gallery and
// uploaded straight away (POST /uploads/photo, /uploads/id-proof); nothing
// changes on the account until Save changes. The photo then saves through
// PATCH /users/me, the ID proof and payout details through PATCH
// /providers/me. The API never sends the ID proof or the payout details back,
// so leaving them alone keeps what is on file. A new ID proof puts the ID
// under review; the account stays active meanwhile.

/// Takes the [details] Profile already loaded and an optional [client], like
/// the other provider screens. Pops with `true` after a successful save.
class PayoutDocumentsScreen extends StatefulWidget {
  final BusinessDetails details;
  final ApiClient? client;

  /// Asks for a photo; tests pass a fake. Defaults to the camera or gallery.
  final PhotoPicker pickPhoto;
  const PayoutDocumentsScreen(
      {super.key,
      required this.details,
      this.client,
      this.pickPhoto = choosePhoto});

  @override
  State<PayoutDocumentsScreen> createState() => _PayoutDocumentsScreenState();
}

class _PayoutDocumentsScreenState extends State<PayoutDocumentsScreen> {
  ApiClient get _api => widget.client ?? api;

  // The photo as it will be saved: the one on file, a new upload, or null.
  late String? _photo = widget.details.profilePhotoUrl;
  String? _newIdProof;
  final _payout = TextEditingController();

  bool _uploadingPhoto = false;
  bool _uploadingId = false;
  bool _clearPayout = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _payout.dispose();
    super.dispose();
  }

  Future<String?> _upload(String path) async {
    final photo = await widget.pickPhoto(context);
    if (photo == null || !mounted) return null;
    try {
      return await _api.upload(path, photo.bytes, photo.name);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = 'Could not upload: ${e.message}');
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not upload: $e');
    }
    return null;
  }

  Future<void> _changePhoto() async {
    setState(() {
      _uploadingPhoto = true;
      _error = null;
    });
    final url = await _upload('/uploads/photo');
    if (!mounted) return;
    setState(() {
      if (url != null) _photo = url;
      _uploadingPhoto = false;
    });
  }

  Future<void> _uploadIdProof() async {
    setState(() {
      _uploadingId = true;
      _error = null;
    });
    final ref = await _upload('/uploads/id-proof');
    if (!mounted) return;
    setState(() {
      if (ref != null) _newIdProof = ref;
      _uploadingId = false;
    });
  }

  Future<void> _save() async {
    final payout = _payout.text.trim();
    if (payout.length > 120) {
      setState(() =>
          _error = 'Bank or UPI details must be 120 characters or fewer.');
      return;
    }

    final business = <String, dynamic>{
      if (_newIdProof != null) 'idProofUrl': _newIdProof,
      if (payout.isNotEmpty)
        'bankOrUpiDetails': payout
      else if (_clearPayout)
        'bankOrUpiDetails': '',
    };
    final photoChanged = _photo != widget.details.profilePhotoUrl;
    if (business.isEmpty && !photoChanged) {
      setState(() => _error = 'Nothing to save yet.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (photoChanged) {
        await _api.patch('/users/me', {'profilePhotoUrl': _photo},
            auth: true);
      }
      if (business.isNotEmpty) {
        await _api.patch('/providers/me', business, auth: true);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final bar = successSnackBar(
          context,
          _newIdProof != null
              ? 'Saved. Your new ID is under review.'
              : 'Saved.');
      Navigator.of(context).pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(bar);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final d = widget.details;
    final hintStyle = OneHubTextStyles.fieldLabel(textMuted)
        .copyWith(letterSpacing: 0, fontSize: 11);

    final (idLabel, idColor) = _newIdProof != null
        ? ('READY TO SAVE', OneHubColors.primary)
        : d.idProofNeedsReview
            ? ('UNDER REVIEW', context.statusWarning)
            : d.idProofOnFile
                ? ('ON FILE', context.statusSuccess)
                : ('NOT ADDED', context.statusDanger);
    final masked = d.bankOrUpiMasked;
    final photo = _photo;
    final busy = _uploadingPhoto || _uploadingId;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Payout & documents')),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Your photo, ID proof and where payouts go.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FieldLabel('PROFILE PHOTO',
                          icon: OneHubIcons.profile),
                      const SizedBox(height: OneHubTheme.gapFieldInternals),
                      Row(
                        children: [
                          ProfileAvatar(
                            key: const Key('photo-preview'),
                            name: d.businessName,
                            photoUrl: photo == null ? null : _api.resolve(photo),
                            busy: _uploadingPhoto,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  key: const Key('change-photo'),
                                  onPressed: busy ? null : _changePhoto,
                                  icon: const Icon(OneHubIcons.camera, size: 16),
                                  label: Text(photo == null
                                      ? 'Add photo'
                                      : 'Change photo'),
                                ),
                                if (photo != null)
                                  TextButton(
                                    key: const Key('remove-photo'),
                                    onPressed: busy
                                        ? null
                                        : () => setState(() => _photo = null),
                                    child: Text('Remove',
                                        style: TextStyle(
                                            color: context.statusDanger)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Without a photo your initial is shown.',
                          style: hintStyle),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      Row(
                        children: [
                          const Expanded(
                            child: FieldLabel('ID PROOF',
                                icon: OneHubIcons.documentList),
                          ),
                          TintedBadge(label: idLabel, color: idColor),
                        ],
                      ),
                      const SizedBox(height: OneHubTheme.gapFieldInternals),
                      OutlinedButton.icon(
                        key: const Key('upload-id-proof'),
                        onPressed: busy ? null : _uploadIdProof,
                        icon: _uploadingId
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(OneHubIcons.camera, size: 16),
                        label: Text(_newIdProof == null
                            ? 'Upload a new ID proof'
                            : 'Choose a different one'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                          'A photo of your Aadhaar or PAN. Only OneHub sees '
                          'it. A new ID is reviewed; you keep receiving '
                          'requests meanwhile.',
                          style: hintStyle),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      const FieldLabel('BANK ACCOUNT OR UPI ID',
                          icon: OneHubIcons.wallet),
                      const SizedBox(height: OneHubTheme.gapFieldInternals),
                      TextField(
                        key: const Key('payout-field'),
                        controller: _payout,
                        enabled: !_clearPayout,
                        decoration: InputDecoration(
                            hintText: masked == null
                                ? 'name@bank or account number'
                                : 'On file: $masked'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                          masked == null
                              ? 'No payout details yet.'
                              : 'Leave empty to keep $masked.',
                          style: hintStyle),
                      // Transparent Material so the tile's ink draws above
                      // the GlowCard's decoration.
                      if (masked != null)
                        Material(
                          type: MaterialType.transparency,
                          child: CheckboxListTile(
                            key: const Key('clear-payout'),
                            value: _clearPayout,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text('Remove my payout details',
                                style:
                                    OneHubTextStyles.bodyText(textSecondary)),
                            onChanged: (v) => setState(() {
                              _clearPayout = v ?? false;
                              if (_clearPayout) _payout.clear();
                              _error = null;
                            }),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(_error!,
                              style: TextStyle(color: context.statusDanger)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryCta(
                  onPressed: _saving || busy ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save changes')),
              const SizedBox(height: 12),
              Text(
                  'Payouts are not sent yet; these details are kept for '
                  'when they are.',
                  textAlign: TextAlign.center,
                  style: OneHubTextStyles.fieldLabel(textMuted)
                      .copyWith(letterSpacing: 0, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
