import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';
import '../../core/widgets/location_field.dart';
import '../../core/widgets/service_picker.dart';

// docx 2.3 — Provider Sign Up. Profile photo upload isn't built (no file
// picker/storage integration yet) — ID proof is a URL field for the same
// reason; both are meant to become real uploads once that exists.
// Three steps instead of one long form: (1) basic details + OTP + password,
// (2) service selection as grids of icon tiles, (3) business details, terms
// and account creation, then a success step. Takes an optional [client] the
// way ResetPasswordScreen does, so the steps can be tested with a fake API.
class SignupScreen extends StatefulWidget {
  final ApiClient? client;

  /// Asks for the ID proof photo; tests pass a fake. Defaults to the camera or
  /// gallery.
  final PhotoPicker pickPhoto;

  /// Asks where the business is; tests pass one to skip the sheet and GPS.
  final LocationPicker? pickLocation;
  const SignupScreen(
      {super.key,
      this.client,
      this.pickPhoto = choosePhoto,
      this.pickLocation});

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
    'Pick your categories, then the services you provide.',
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
  // The uploaded ID proof's reference, from POST /uploads/id-proof. That
  // route is open because the account does not exist yet; the file is
  // private and never served.
  String? _idProof;
  SavedLocation? _location;
  bool _uploadingId = false;
  final _bankOrUpiDetails = TextEditingController();

  List<ServiceCategory> _categories = [];
  // Every category the provider works in, and the services they offer.
  final Set<String> _selectedCategoryIds = {};
  final Set<String> _selectedSubServiceIds = {};

  int _step = 0;
  bool _otpSent = false;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _busy = false;
  bool _loadingCategories = true;
  bool _created = false;
  // A problem that belongs to no field (no connection, a server fault),
  // shown above the form.
  String? _error;
  // Problems shown under their own field, keyed by field name.
  final Map<String, String> _fieldErrors = {};
  // The code the API sent back while no SMS is sent (never in production).
  String? _testCode;

  // Which step each field is on, so a refusal at Create Account can take the
  // user back to the field it is about.
  static const _fieldStep = {
    'name': 0, 'mobile': 0, 'otp': 0, 'email': 0, 'password': 0, 'confirm': 0,
    'services': 1,
  };
  static const _apiFields = {
    'otp': ['otp', 'code'],
    'mobile': ['mobile'],
    'email': ['email'],
    'confirm': ['match'],
    'password': ['password'],
    'location': ['business is'],
    'services': ['sub-service', 'category'],
    'idProof': ['id proof', 'idproof', 'image', 'jpeg'],
  };

  void _clear(String field) {
    if (_fieldErrors.remove(field) != null) setState(() {});
  }

  // Shows [e] under its field (moving to that field's step), else above the
  // form.
  void _fail(Object e) {
    final field = errorField(e, _apiFields);
    setState(() {
      if (field == null) {
        _error = userMessage(e);
      } else {
        _fieldErrors[field] = userMessage(e);
        _step = _fieldStep[field] ?? _step;
      }
    });
  }

  ApiClient get _api => widget.client ?? api;

  Future<void> _chooseLocation() async {
    final pick = widget.pickLocation ??
        (BuildContext context, SavedLocation? current) =>
            chooseLocation(context, _api, current: current);
    final picked = await pick(context, _location);
    if (picked != null && mounted) {
      setState(() {
        _location = picked;
        _fieldErrors.remove('location');
      });
    }
  }

  Future<void> _uploadIdProof() async {
    final photo = await widget.pickPhoto(context);
    if (photo == null || !mounted) return;
    setState(() {
      _uploadingId = true;
      _fieldErrors.remove('idProof');
    });
    try {
      final ref = await _api.upload('/uploads/id-proof', photo.bytes, photo.name,
          auth: false);
      if (mounted) setState(() => _idProof = ref);
    } catch (e) {
      if (mounted) {
        setState(() => _fieldErrors['idProof'] =
            'Could not upload that photo. ${userMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _uploadingId = false);
    }
  }

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
        _error = 'Could not load the service categories. ${userMessage(e)}';
        _loadingCategories = false;
      });
    }
  }

  Future<void> _sendOtp() async {
    if (!RegExp(r'^[0-9]{10}$').hasMatch(_mobile.text.trim())) {
      setState(() => _fieldErrors['mobile'] = 'Enter a 10-digit mobile number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors.remove('mobile');
    });
    try {
      final reply =
          await _api.post('/auth/otp/request', {'mobile': _mobile.text.trim()});
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _testCode = testCodeFrom(reply);
        _fieldErrors.remove('otp');
      });
    } catch (e) {
      if (!mounted) return;
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Every problem on [step], keyed by the field it belongs to.
  Map<String, String> _validateStep(int step) {
    switch (step) {
      case 0:
        final mobileOk = RegExp(r'^[0-9]{10}$').hasMatch(_mobile.text.trim());
        final email = _email.text.trim();
        return {
          if (_businessName.text.trim().isEmpty)
            'name': 'Enter your name or business name.',
          if (!mobileOk) 'mobile': 'Enter a 10-digit mobile number.',
          if (mobileOk && !_otpSent)
            'otp': 'Tap Send OTP to get a code on this number.',
          if (_otpSent && _otp.text.trim().length != 6)
            'otp': 'Enter the 6-digit code.',
          if (email.isNotEmpty &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))
            'email': 'Enter a valid email address.',
          if (_password.text.length < 6)
            'password': 'Password must be at least 6 characters.',
          if (_password.text != _confirmPassword.text)
            'confirm': 'The passwords do not match.',
        };
      case 1:
        return {
          if (_selectedCategoryIds.isEmpty)
            'services': 'Choose at least one service category.'
          else if (_selectedSubServiceIds.isEmpty)
            'services': 'Choose at least one service you offer.',
        };
      default:
        return {
          if (_location == null) 'location': 'Choose where your business is.',
          if (_idProof == null)
            'idProof': 'Upload a photo of your ID proof for verification.',
          if (!_acceptedTerms)
            'terms': 'Accept the Terms & Conditions to continue.',
        };
    }
  }

  void _next() {
    final problems = _validateStep(_step);
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(problems);
      _error = null;
      if (problems.isEmpty) _step += 1;
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
      _fieldErrors.clear();
    });
  }

  Future<void> _createAccount() async {
    final problems = _validateStep(2);
    if (problems.isNotEmpty) {
      setState(() {
        _fieldErrors
          ..clear()
          ..addAll(problems);
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors.clear();
    });
    try {
      await _api.post('/auth/provider/signup', {
        'fullNameOrBusinessName': _businessName.text.trim(),
        'mobile': _mobile.text.trim(),
        'otp': _otp.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        'password': _password.text,
        'confirmPassword': _confirmPassword.text,
        'subServiceIds': _selectedSubServiceIds.toList(),
        if (_yearsExperience.text.trim().isNotEmpty)
          'yearsExperience': int.tryParse(_yearsExperience.text.trim()),
        'coverageRadiusKm': double.tryParse(_coverageRadiusKm.text.trim()) ?? 5,
        'latitude': _location!.latitude,
        'longitude': _location!.longitude,
        'city': _location!.city,
        'idProofUrl': _idProof,
        if (_bankOrUpiDetails.text.trim().isNotEmpty)
          'bankOrUpiDetails': _bankOrUpiDetails.text.trim(),
      });
      if (!mounted) return;
      setState(() => _created = true);
    } catch (e) {
      if (!mounted) return;
      _fail(e);
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
                onChanged: (_) => _clear('name'),
                decoration: InputDecoration(
                    hintText: 'John Doe', errorText: _fieldErrors['name'])),
            const SizedBox(height: OneHubTheme.sectionGap),
            const FieldLabel('MOBILE NUMBER',
                required: true, icon: OneHubIcons.phone),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                    enabled: !_otpSent,
                    onChanged: (_) => _clear('mobile'),
                    decoration: InputDecoration(
                        hintText: '10-digit number',
                        errorText: _fieldErrors['mobile']),
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
              onChanged: (_) => _clear('otp'),
              decoration: InputDecoration(
                hintText: _otpSent ? '6-digit code' : 'Tap Send OTP first',
                counterText: '',
                errorText: _fieldErrors['otp'],
              ),
            ),
            TestCodeHint(_testCode),
            const SizedBox(height: OneHubTheme.sectionGap),
            const FieldLabel('EMAIL ID (optional)', icon: OneHubIcons.email),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => _clear('email'),
              decoration: InputDecoration(
                  hintText: 'you@example.com',
                  errorText: _fieldErrors['email']),
            ),
            const SizedBox(height: OneHubTheme.sectionGap),
            const FieldLabel('PASSWORD',
                required: true, icon: OneHubIcons.lock),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            TextField(
              controller: _password,
              obscureText: _obscurePassword,
              onChanged: (_) => _clear('password'),
              decoration: InputDecoration(
                hintText: 'Min. 6 chars',
                errorText: _fieldErrors['password'],
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
              onChanged: (_) => _clear('confirm'),
              decoration: InputDecoration(
                hintText: 'Re-enter',
                errorText: _fieldErrors['confirm'],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _errorText(),
        if (_loadingCategories)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()))
        else
          ServicePicker(
            api: _api,
            categories: _categories,
            categoryIds: _selectedCategoryIds,
            serviceIds: _selectedSubServiceIds,
            onChanged: () => setState(() => _fieldErrors.remove('services')),
            heading: (text) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(text,
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 18)),
            ),
          ),
        FieldError(_fieldErrors['services']),
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
            const FieldLabel('BUSINESS LOCATION',
                required: true, icon: OneHubIcons.location),
            const SizedBox(height: OneHubTheme.gapFieldInternals),
            LocationField(
                location: _location,
                onPressed: _busy ? null : _chooseLocation),
            FieldError(_fieldErrors['location']),
            const SizedBox(height: 6),
            Text('Distances to customers are measured from here.',
                style: OneHubTextStyles.fieldLabel(textSecondary)
                    .copyWith(letterSpacing: 0, fontSize: 11)),
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
            Row(
              children: [
                OutlinedButton.icon(
                  key: const Key('upload-id-proof'),
                  onPressed: _uploadingId || _busy ? null : _uploadIdProof,
                  icon: _uploadingId
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(OneHubIcons.camera, size: 16),
                  label: Text(_idProof == null
                      ? 'Upload a photo'
                      : 'Choose a different one'),
                ),
                if (_idProof != null) ...[
                  const SizedBox(width: 12),
                  TintedBadge(label: 'ADDED', color: context.statusSuccess),
                ],
              ],
            ),
            FieldError(_fieldErrors['idProof']),
            const SizedBox(height: 6),
            Text('Only OneHub sees it, to verify your account.',
                style: OneHubTextStyles.fieldLabel(textSecondary)
                    .copyWith(letterSpacing: 0, fontSize: 11)),
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
                  onChanged: (v) => setState(() {
                    _acceptedTerms = v ?? false;
                    _fieldErrors.remove('terms');
                  }),
                ),
                Expanded(
                  child: TermsAgreementText(
                      lead: 'I accept the ',
                      privacy: false,
                      textColor: textSecondary,
                      linkColor: primary),
                ),
              ],
            ),
            FieldError(_fieldErrors['terms']),
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
