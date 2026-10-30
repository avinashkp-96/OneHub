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
// There is no file storage yet, so the photo and the ID proof are links, as at
// signup. The photo saves through PATCH /users/me; the ID proof and payout
// details through PATCH /providers/me. The API never sends the ID link or the
// payout details back, so those two fields start empty and leaving one empty
// keeps what is on file. A new ID link puts the ID under review; the account
// stays active meanwhile.

/// Takes the [details] Profile already loaded and an optional [client], like
/// the other provider screens. Pops with `true` after a successful save.
class PayoutDocumentsScreen extends StatefulWidget {
  final BusinessDetails details;
  final ApiClient? client;
  const PayoutDocumentsScreen({super.key, required this.details, this.client});

  @override
  State<PayoutDocumentsScreen> createState() => _PayoutDocumentsScreenState();
}

class _PayoutDocumentsScreenState extends State<PayoutDocumentsScreen> {
  ApiClient get _api => widget.client ?? api;

  late final _photo =
      TextEditingController(text: widget.details.profilePhotoUrl ?? '');
  final _idProof = TextEditingController();
  final _payout = TextEditingController();

  bool _clearPayout = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _photo.dispose();
    _idProof.dispose();
    _payout.dispose();
    super.dispose();
  }

  static bool _looksLikeLink(String v) =>
      RegExp(r'^https?://\S+\.\S+$').hasMatch(v);

  Future<void> _save() async {
    final photo = _photo.text.trim();
    final idProof = _idProof.text.trim();
    final payout = _payout.text.trim();

    String? problem;
    if (photo.isNotEmpty && !_looksLikeLink(photo)) {
      problem = 'The photo link must start with http:// or https://.';
    } else if (idProof.isNotEmpty && !_looksLikeLink(idProof)) {
      problem = 'The ID proof link must start with http:// or https://.';
    } else if (payout.length > 120) {
      problem = 'Bank or UPI details must be 120 characters or fewer.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final business = <String, dynamic>{
      if (idProof.isNotEmpty) 'idProofUrl': idProof,
      if (payout.isNotEmpty)
        'bankOrUpiDetails': payout
      else if (_clearPayout)
        'bankOrUpiDetails': '',
    };
    final photoChanged = photo != (widget.details.profilePhotoUrl ?? '');
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
        await _api.patch(
            '/users/me', {'profilePhotoUrl': photo.isEmpty ? null : photo},
            auth: true);
      }
      if (business.isNotEmpty) {
        await _api.patch('/providers/me', business, auth: true);
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final bar = successSnackBar(
          context,
          idProof.isNotEmpty
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

    final (idLabel, idColor) = d.idProofNeedsReview
        ? ('UNDER REVIEW', context.statusWarning)
        : d.idProofOnFile
            ? ('ON FILE', context.statusSuccess)
            : ('NOT ADDED', context.statusDanger);
    final masked = d.bankOrUpiMasked;

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
                      const FieldLabel('PROFILE PHOTO LINK',
                          icon: OneHubIcons.profile),
                      const SizedBox(height: OneHubTheme.gapFieldInternals),
                      TextField(
                        key: const Key('photo-field'),
                        controller: _photo,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                            hintText: 'https://example.com/photo.jpg'),
                      ),
                      const SizedBox(height: 6),
                      Text('Leave empty to show your initial instead.',
                          style: hintStyle),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      Row(
                        children: [
                          const Expanded(
                            child: FieldLabel('ID PROOF LINK',
                                icon: OneHubIcons.documentList),
                          ),
                          TintedBadge(label: idLabel, color: idColor),
                        ],
                      ),
                      const SizedBox(height: OneHubTheme.gapFieldInternals),
                      TextField(
                        key: const Key('id-proof-field'),
                        controller: _idProof,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                            hintText: 'Link to a new ID proof'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                          'Leave empty to keep the one on file. A new ID is '
                          'reviewed by OneHub; you keep receiving requests '
                          'meanwhile.',
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
                  onPressed: _saving ? null : _save,
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
