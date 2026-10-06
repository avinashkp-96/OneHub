import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';

// docx 2.3 — Provider Sign Up. Profile photo upload isn't built (no file
// picker/storage integration yet) — ID proof is a URL field for the same
// reason; both are meant to become real uploads once that exists.
// Restyled to match the customer app's signup screen (no new reference —
// applied on request): PageGlow, back-only AppBar plus in-body heading, one
// GlowCard holding the whole form with FieldLabel-above-field inputs, and a
// success step replacing the old AlertDialog. The category list loads
// inline in its own field instead of gating the whole form behind a spinner.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _businessName = TextEditingController();
  final _mobile = TextEditingController();
  final _otp = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _yearsExperience = TextEditingController();
  final _coverageRadiusKm = TextEditingController(text: '5');
  final _idProofUrl = TextEditingController();
  final _bankOrUpiDetails = TextEditingController();

  List<ServiceCategory> _categories = [];
  List<SubService> _subServices = [];
  String? _selectedCategoryId;
  final Set<String> _selectedSubServiceIds = {};

  bool _otpSent = false;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _busy = false;
  bool _loadingCategories = true;
  bool _created = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final json = await api.get('/categories') as List;
      if (!mounted) return;
      setState(() {
        _categories = json
            .map((c) => ServiceCategory.fromJson(c as Map<String, dynamic>))
            .toList();
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load service categories: $e';
        _loadingCategories = false;
      });
    }
  }

  Future<void> _selectCategory(String categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedSubServiceIds.clear();
      _subServices = [];
    });
    try {
      final json =
          await api.get('/categories/$categoryId/sub-services') as List;
      if (!mounted) return;
      setState(() => _subServices = json
          .map((s) => SubService.fromJson(s as Map<String, dynamic>))
          .toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load sub-services: $e');
    }
  }

  Future<void> _sendOtp() async {
    if (!RegExp(r'^[0-9]{10}$').hasMatch(_mobile.text.trim())) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.post('/auth/otp/request', {'mobile': _mobile.text.trim()});
      if (!mounted) return;
      setState(() => _otpSent = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not send an OTP: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createAccount() async {
    if (!_otpSent) {
      setState(() => _error = 'Verify your mobile number first.');
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Password and confirmation must match.');
      return;
    }
    if (_selectedCategoryId == null || _selectedSubServiceIds.isEmpty) {
      setState(() =>
          _error = 'Select a service category and at least one sub-service.');
      return;
    }
    if (_idProofUrl.text.trim().isEmpty) {
      setState(() => _error = 'ID proof is required for verification.');
      return;
    }
    if (!_acceptedTerms) {
      setState(() => _error = 'Accept the Terms & Conditions to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.post('/auth/provider/signup', {
        'fullNameOrBusinessName': _businessName.text.trim(),
        'mobile': _mobile.text.trim(),
        'otp': _otp.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        'password': _password.text,
        'confirmPassword': _confirmPassword.text,
        'categoryId': _selectedCategoryId,
        'subServiceIds': _selectedSubServiceIds.toList(),
        if (_yearsExperience.text.trim().isNotEmpty)
          'yearsExperience': int.tryParse(_yearsExperience.text.trim()),
        'coverageRadiusKm': double.tryParse(_coverageRadiusKm.text.trim()) ?? 5,
        // TODO: capture real GPS coordinates instead of a fixed placeholder
        // once location permission handling is built.
        'latitude': 0,
        'longitude': 0,
        'idProofUrl': _idProofUrl.text.trim(),
        if (_bankOrUpiDetails.text.trim().isNotEmpty)
          'bankOrUpiDetails': _bankOrUpiDetails.text.trim(),
      });
      if (!mounted) return;
      setState(() => _created = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not create your account: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: _created
              ? _SuccessStep(onBackToLogin: () => Navigator.of(context).pop())
              : ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: OneHubTheme.pageMargin,
                      vertical: OneHubTheme.pagePaddingY),
                  children: [
                    Text('Create Provider Account',
                        textAlign: TextAlign.center,
                        style: OneHubTextStyles.pageHeading(textPrimary)),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us about your services. An admin verifies your ID before you go live.',
                      textAlign: TextAlign.center,
                      style: OneHubTextStyles.bodyText(textSecondary),
                    ),
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
                                    style:
                                        TextStyle(color: context.statusDanger)),
                              ),
                            const FieldLabel('FULL NAME / BUSINESS NAME',
                                required: true, icon: OneHubIcons.user),
                            const SizedBox(
                                height: OneHubTheme.gapFieldInternals),
                            TextField(
                                controller: _businessName,
                                decoration: const InputDecoration(
                                    hintText: 'John Doe')),
                            const SizedBox(height: OneHubTheme.sectionGap),
                            const FieldLabel('MOBILE NUMBER',
                                required: true, icon: OneHubIcons.phone),
                            const SizedBox(
                                height: OneHubTheme.gapFieldInternals),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _mobile,
                                    keyboardType: TextInputType.phone,
                                    enabled: !_otpSent,
                                    decoration: const InputDecoration(
                                        hintText: '10-digit number'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed:
                                      _otpSent || _busy ? null : _sendOtp,
                                  child: Text(_otpSent ? 'Sent' : 'Send OTP'),
                                ),
                              ],
                            ),
                            if (_otpSent) ...[
                              const SizedBox(height: OneHubTheme.sectionGap),
                              const FieldLabel('OTP',
                                  required: true, icon: OneHubIcons.confirmed),
                              const SizedBox(
                                  height: OneHubTheme.gapFieldInternals),
                              TextField(
                                controller: _otp,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    hintText: '6-digit code'),
                              ),
                            ],
                            const SizedBox(height: OneHubTheme.sectionGap),
                            const FieldLabel('EMAIL ID (optional)',
                                icon: OneHubIcons.email),
                            const SizedBox(
                                height: OneHubTheme.gapFieldInternals),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                  hintText: 'you@example.com'),
                            ),
                            const SizedBox(height: OneHubTheme.sectionGap),
                            const FieldLabel('PASSWORD',
                                required: true, icon: OneHubIcons.lock),
                            const SizedBox(
                                height: OneHubTheme.gapFieldInternals),
                            TextField(
                              controller: _password,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: 'Min. 6 chars',
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? OneHubIcons.hide
                                      : OneHubIcons.show),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: OneHubTheme.sectionGap),
                            const FieldLabel('CONFIRM PASSWORD',
                                required: true, icon: OneHubIcons.confirmed),
                            const SizedBox(
                                height: OneHubTheme.gapFieldInternals),
                            TextField(
                              controller: _confirmPassword,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                hintText: 'Re-enter',
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirmPassword
                                      ? OneHubIcons.hide
                                      : OneHubIcons.show),
                                  onPressed: () => setState(() =>
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text('Your services',
                                style: OneHubTextStyles.pageHeading(textPrimary)
                                    .copyWith(fontSize: 18)),
                            const SizedBox(height: OneHubTheme.sectionGap),
                            const FieldLabel('SERVICE CATEGORY',
                                required: true, icon: OneHubIcons.category),
                            const SizedBox(
                                height: OneHubTheme.gapFieldInternals),
                            if (_loadingCategories)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            else
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                hint: const Text('Select a category'),
                                initialValue: _selectedCategoryId,
                                items: _categories
                                    .map((c) => DropdownMenuItem(
                                        value: c.id, child: Text(c.name)))
                                    .toList(),
                                onChanged: (id) {
                                  if (id != null) _selectCategory(id);
                                },
                              ),
                            if (_selectedCategoryId != null) ...[
                              const SizedBox(height: OneHubTheme.sectionGap),
                              const FieldLabel('SUB-SERVICES OFFERED',
                                  required: true, icon: OneHubIcons.work),
                              const SizedBox(
                                  height: OneHubTheme.gapFieldInternals),
                              for (final s in _subServices)
                                _SelectableRow(
                                  label: s.name,
                                  selected:
                                      _selectedSubServiceIds.contains(s.id),
                                  onTap: () => setState(() {
                                    if (!_selectedSubServiceIds.remove(s.id))
                                      _selectedSubServiceIds.add(s.id);
                                  }),
                                ),
                            ],
                            const SizedBox(height: 28),
                            Text('Business details',
                                style: OneHubTextStyles.pageHeading(textPrimary)
                                    .copyWith(fontSize: 18)),
                            const SizedBox(height: OneHubTheme.sectionGap),
                            const FieldLabel('YEARS OF EXPERIENCE (optional)',
                                icon: OneHubIcons.calendar),
                            const SizedBox(
                                height: OneHubTheme.gapFieldInternals),
                            TextField(
                              controller: _yearsExperience,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(hintText: 'e.g. 5'),
                            ),
                            const SizedBox(height: OneHubTheme.sectionGap),
                            const FieldLabel('COVERAGE RADIUS (km)',
                                icon: OneHubIcons.location),
                            const SizedBox(
                                height: OneHubTheme.gapFieldInternals),
                            TextField(
                              controller: _coverageRadiusKm,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(hintText: 'e.g. 5'),
                            ),
                            const SizedBox(height: OneHubTheme.sectionGap),
                            const FieldLabel('ID PROOF (AADHAAR / PAN)',
                                required: true, icon: OneHubIcons.documentList),
                            const SizedBox(
                                height: OneHubTheme.gapFieldInternals),
                            TextField(
                                controller: _idProofUrl,
                                decoration: const InputDecoration(
                                    hintText: 'Document link')),
                            const SizedBox(height: OneHubTheme.sectionGap),
                            const FieldLabel('BANK / UPI DETAILS (optional)',
                                icon: OneHubIcons.wallet),
                            const SizedBox(
                                height: OneHubTheme.gapFieldInternals),
                            TextField(
                              controller: _bankOrUpiDetails,
                              decoration: const InputDecoration(
                                  hintText: 'Can be added later'),
                            ),
                            const SizedBox(height: OneHubTheme.sectionGap),
                            Row(
                              children: [
                                Checkbox(
                                  value: _acceptedTerms,
                                  onChanged: (v) => setState(
                                      () => _acceptedTerms = v ?? false),
                                ),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      style: OneHubTextStyles.bodyText(
                                          textSecondary),
                                      children: [
                                        const TextSpan(text: 'I accept the '),
                                        TextSpan(
                                            text: 'Terms & Conditions',
                                            style: OneHubTextStyles.linkText(
                                                primary)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            PrimaryCta(
                                onPressed: _busy ? null : _createAccount,
                                child: const Text('Create Account')),
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

class _SelectableRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectableRow(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final border =
        dark ? OneHubColors.inputBorderDark : OneHubColors.inputBorderLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusInputField),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: OneHubTheme.fieldPaddingX, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(OneHubTheme.radiusInputField),
            border: Border.all(color: selected ? OneHubColors.primary : border),
          ),
          child: Row(
            children: [
              Icon(selected ? OneHubIcons.confirmed : OneHubIcons.plus,
                  size: 18, color: selected ? OneHubColors.primary : textMuted),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: OneHubTextStyles.bodyText(textPrimary))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  final VoidCallback onBackToLogin;
  const _SuccessStep({required this.onBackToLogin});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OneHubTheme.pageMargin),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                  color: context.statusSuccess.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: Icon(OneHubIcons.successCheck,
                  color: context.statusSuccess, size: 48),
            ),
          ),
          const SizedBox(height: 24),
          Text('Account Created!',
              textAlign: TextAlign.center,
              style: OneHubTextStyles.pageHeading(textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Your account is pending verification. You can log in once an admin approves your ID proof.',
            textAlign: TextAlign.center,
            style: OneHubTextStyles.bodyText(textSecondary),
          ),
          const SizedBox(height: OneHubTheme.sectionGap),
          PrimaryCta(
              onPressed: onBackToLogin, child: const Text('Back to Login')),
        ],
      ),
    );
  }
}
