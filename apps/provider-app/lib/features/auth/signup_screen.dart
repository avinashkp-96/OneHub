import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';

// docx 2.3 — Provider Sign Up. Profile photo upload isn't built (no file
// picker/storage integration yet) — ID proof is a URL field for the same
// reason; both are meant to become real uploads once that exists.
// Three steps instead of one long form: (1) basic details + OTP + password,
// (2) service selection as grids of icon tiles, (3) business details, terms
// and account creation, then a success step. Takes an optional [client] the
// way ResetPasswordScreen does, so the steps can be tested with a fake API.
class SignupScreen extends StatefulWidget {
  final ApiClient? client;
  const SignupScreen({super.key, this.client});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const _stepCount = 3;
  static const _stepTitles = [
    'Create Provider Account',
    'What do you offer?',
    'Business details',
  ];
  static const _stepSubtitles = [
    'Start with your details and a password.',
    'Pick your category, then the services you provide.',
    'An admin verifies your ID before you go live.',
  ];

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

  int _step = 0;
  bool _otpSent = false;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _busy = false;
  bool _loadingCategories = true;
  bool _loadingSubServices = false;
  bool _created = false;
  String? _error;

  ApiClient get _api => widget.client ?? api;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final json = await _api.get('/categories') as List;
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
    if (categoryId == _selectedCategoryId) return;
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedSubServiceIds.clear();
      _subServices = [];
      _loadingSubServices = true;
      _error = null;
    });
    try {
      final json =
          await _api.get('/categories/$categoryId/sub-services') as List;
      if (!mounted) return;
      setState(() {
        _subServices = json
            .map((s) => SubService.fromJson(s as Map<String, dynamic>))
            .toList();
        _loadingSubServices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load sub-services: $e';
        _loadingSubServices = false;
      });
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
      await _api.post('/auth/otp/request', {'mobile': _mobile.text.trim()});
      if (!mounted) return;
      setState(() => _otpSent = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not send an OTP: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateStep(int step) {
    switch (step) {
      case 0:
        if (_businessName.text.trim().isEmpty) {
          return 'Enter your name or business name.';
        }
        if (!RegExp(r'^[0-9]{10}$').hasMatch(_mobile.text.trim())) {
          return 'Enter a valid 10-digit mobile number.';
        }
        if (!_otpSent) return 'Tap Send OTP to verify your mobile number.';
        if (_otp.text.trim().length != 6) return 'Enter the 6-digit code.';
        if (_password.text.length < 6) {
          return 'Password must be at least 6 characters.';
        }
        if (_password.text != _confirmPassword.text) {
          return 'Password and confirmation must match.';
        }
        return null;
      case 1:
        if (_selectedCategoryId == null || _selectedSubServiceIds.isEmpty) {
          return 'Select a service category and at least one service.';
        }
        return null;
      default:
        if (_idProofUrl.text.trim().isEmpty) {
          return 'ID proof is required for verification.';
        }
        if (!_acceptedTerms) {
          return 'Accept the Terms & Conditions to continue.';
        }
        return null;
    }
  }

  void _next() {
    final error = _validateStep(_step);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _step += 1;
      _error = null;
    });
  }

  void _back() {
    if (_step == 0 || _created) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _step -= 1;
      _error = null;
    });
  }

  Future<void> _createAccount() async {
    final error = _validateStep(2);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.post('/auth/provider/signup', {
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

    return PopScope(
      canPop: _step == 0 || _created,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: _back)),
        body: PageGlow(
          child: SafeArea(
            child: _created
                ? _SuccessStep(onBackToLogin: () => Navigator.of(context).pop())
                : ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: OneHubTheme.pageMargin,
                        vertical: OneHubTheme.pagePaddingY),
                    children: [
                      _StepIndicator(current: _step, total: _stepCount),
                      const SizedBox(height: 20),
                      Text(_stepTitles[_step],
                          textAlign: TextAlign.center,
                          style: OneHubTextStyles.pageHeading(textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                        _stepSubtitles[_step],
                        textAlign: TextAlign.center,
                        style: OneHubTextStyles.bodyText(textSecondary),
                      ),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      if (_step == 0) _buildBasicStep(),
                      if (_step == 1) _buildServicesStep(textPrimary),
                      if (_step == 2) _buildBusinessStep(textSecondary),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _errorText() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(_error!, style: TextStyle(color: context.statusDanger)),
        );

  Widget _buildBasicStep() {
    return GlowCard(
      child: Padding(
        padding: const EdgeInsets.all(OneHubTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _errorText(),
            const FieldLabel('FULL NAME / BUSINESS NAME',
                required: true, icon: OneHubIcons.user),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            TextField(
                controller: _businessName,
                decoration: const InputDecoration(hintText: 'John Doe')),
            const SizedBox(height: OneHubTheme.sectionGap),
            const FieldLabel('MOBILE NUMBER',
                required: true, icon: OneHubIcons.phone),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                    enabled: !_otpSent,
                    decoration:
                        const InputDecoration(hintText: '10-digit number'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _otpSent || _busy ? null : _sendOtp,
                  child: Text(_otpSent ? 'Sent' : 'Send OTP'),
                ),
              ],
            ),
            const SizedBox(height: OneHubTheme.sectionGap),
            const FieldLabel('OTP',
                required: true, icon: OneHubIcons.confirmed),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            TextField(
              controller: _otp,
              enabled: _otpSent,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: _otpSent ? '6-digit code' : 'Tap Send OTP first',
                counterText: '',
              ),
            ),
            const SizedBox(height: OneHubTheme.sectionGap),
            const FieldLabel('EMAIL ID (optional)', icon: OneHubIcons.email),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'you@example.com'),
            ),
            const SizedBox(height: OneHubTheme.sectionGap),
            const FieldLabel('PASSWORD',
                required: true, icon: OneHubIcons.lock),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            TextField(
              controller: _password,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Min. 6 chars',
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscurePassword ? OneHubIcons.hide : OneHubIcons.show),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: OneHubTheme.sectionGap),
            const FieldLabel('CONFIRM PASSWORD',
                required: true, icon: OneHubIcons.confirmed),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            TextField(
              controller: _confirmPassword,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                hintText: 'Re-enter',
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword
                      ? OneHubIcons.hide
                      : OneHubIcons.show),
                  onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
            ),
            const SizedBox(height: OneHubTheme.sectionGap),
            PrimaryCta(onPressed: _next, child: const Text('Continue')),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesStep(Color textPrimary) {
    final warning = context.statusWarning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _errorText(),
        Text('Category',
            style: OneHubTextStyles.pageHeading(textPrimary)
                .copyWith(fontSize: 18)),
        const SizedBox(height: 12),
        if (_loadingCategories)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()))
        else if (_categories.isEmpty)
          Text('No service categories are available yet.',
              style: OneHubTextStyles.bodyText(warning))
        else
          _ServiceGrid(
            children: [
              for (final c in _categories)
                _ServiceTile(
                  label: c.name,
                  imageUrl: c.iconUrl,
                  fallbackIcon: OneHubIcons.category,
                  selected: c.id == _selectedCategoryId,
                  onTap: () => _selectCategory(c.id),
                ),
            ],
          ),
        if (_selectedCategoryId != null) ...[
          const SizedBox(height: 28),
          Text('Services you offer',
              style: OneHubTextStyles.pageHeading(textPrimary)
                  .copyWith(fontSize: 18)),
          const SizedBox(height: 4),
          Text('Select all that apply.',
              style: OneHubTextStyles.bodyText(
                  textPrimary.withValues(alpha: 0.6))),
          const SizedBox(height: 12),
          if (_loadingSubServices)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()))
          else if (_subServices.isEmpty)
            Text('No services listed under this category yet.',
                style: OneHubTextStyles.bodyText(warning))
          else
            _ServiceGrid(
              children: [
                for (final s in _subServices)
                  _ServiceTile(
                    label: s.name,
                    fallbackIcon: OneHubIcons.work,
                    selected: _selectedSubServiceIds.contains(s.id),
                    onTap: () => setState(() {
                      if (!_selectedSubServiceIds.remove(s.id)) {
                        _selectedSubServiceIds.add(s.id);
                      }
                      _error = null;
                    }),
                  ),
              ],
            ),
        ],
        const SizedBox(height: OneHubTheme.sectionGap),
        PrimaryCta(onPressed: _next, child: const Text('Continue')),
      ],
    );
  }

  Widget _buildBusinessStep(Color textSecondary) {
    final primary = Theme.of(context).colorScheme.primary;
    return GlowCard(
      child: Padding(
        padding: const EdgeInsets.all(OneHubTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _errorText(),
            const FieldLabel('YEARS OF EXPERIENCE (optional)',
                icon: OneHubIcons.calendar),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            TextField(
              controller: _yearsExperience,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'e.g. 5'),
            ),
            const SizedBox(height: OneHubTheme.sectionGap),
            const FieldLabel('COVERAGE RADIUS (km)',
                icon: OneHubIcons.location),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            TextField(
              controller: _coverageRadiusKm,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'e.g. 5'),
            ),
            const SizedBox(height: OneHubTheme.sectionGap),
            const FieldLabel('ID PROOF (AADHAAR / PAN)',
                required: true, icon: OneHubIcons.documentList),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            TextField(
                controller: _idProofUrl,
                decoration: const InputDecoration(hintText: 'Document link')),
            const SizedBox(height: OneHubTheme.sectionGap),
            const FieldLabel('BANK / UPI DETAILS (optional)',
                icon: OneHubIcons.wallet),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            TextField(
              controller: _bankOrUpiDetails,
              decoration: const InputDecoration(hintText: 'Can be added later'),
            ),
            const SizedBox(height: OneHubTheme.sectionGap),
            Row(
              children: [
                Checkbox(
                  value: _acceptedTerms,
                  onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: OneHubTextStyles.bodyText(textSecondary),
                      children: [
                        const TextSpan(text: 'I accept the '),
                        TextSpan(
                            text: 'Terms & Conditions',
                            style: OneHubTextStyles.linkText(primary)),
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
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lineColor =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: i <= current ? OneHubColors.primary : lineColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('STEP ${current + 1} OF $total',
            style: OneHubTextStyles.fieldLabel(textMuted)),
      ],
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  final List<Widget> children;
  const _ServiceGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: children,
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final IconData fallbackIcon;
  final bool selected;
  final VoidCallback onTap;
  const _ServiceTile({
    required this.label,
    required this.fallbackIcon,
    required this.selected,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final iconFill =
        dark ? OneHubColors.cardFillDark : OneHubColors.cardFillLight;
    final cardBorder =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        side: BorderSide(
            color: selected ? OneHubColors.primary : cardBorder,
            width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconFill,
                      border: Border.all(color: cardBorder),
                      image: imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(imageUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: imageUrl == null
                        ? Icon(fallbackIcon, color: textPrimary, size: 18)
                        : null,
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(OneHubIcons.confirmed,
                        size: 20, color: OneHubColors.primary),
                ],
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: OneHubTextStyles.bodyText(textPrimary)
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
              ),
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
