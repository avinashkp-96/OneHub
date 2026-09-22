import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';

// docx 2.3 — Provider Sign Up. Profile photo upload isn't built (no file
// picker/storage integration yet) — ID proof is a URL field for the same
// reason; both are meant to become real uploads once that exists.
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
  bool _busy = false;
  bool _loadingCategories = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final json = await api.get('/categories') as List;
      setState(() {
        _categories = json.map((c) => ServiceCategory.fromJson(c as Map<String, dynamic>)).toList();
        _loadingCategories = false;
      });
    } catch (e) {
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
      final json = await api.get('/categories/$categoryId/sub-services') as List;
      setState(() => _subServices = json.map((s) => SubService.fromJson(s as Map<String, dynamic>)).toList());
    } catch (e) {
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
      setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _error = 'Could not send an OTP: $e');
    } finally {
      setState(() => _busy = false);
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
      setState(() => _error = 'Select a service category and at least one sub-service.');
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
        if (_yearsExperience.text.trim().isNotEmpty) 'yearsExperience': int.tryParse(_yearsExperience.text.trim()),
        'coverageRadiusKm': double.tryParse(_coverageRadiusKm.text.trim()) ?? 5,
        // TODO: capture real GPS coordinates instead of a fixed placeholder
        // once location permission handling is built.
        'latitude': 0,
        'longitude': 0,
        'idProofUrl': _idProofUrl.text.trim(),
        if (_bankOrUpiDetails.text.trim().isNotEmpty) 'bankOrUpiDetails': _bankOrUpiDetails.text.trim(),
      });
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Account created'),
            content: const Text(
              'Your account is Pending Verification. You can log in once an admin approves your ID proof.',
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = 'Could not create your account: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Provider Account')),
      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, style: TextStyle(color: context.statusDanger)),
                  ),
                TextField(
                  controller: _businessName,
                  decoration: const InputDecoration(labelText: 'Full Name / Business Name'),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mobile,
                        keyboardType: TextInputType.phone,
                        enabled: !_otpSent,
                        decoration: const InputDecoration(labelText: 'Mobile Number'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: _otpSent || _busy ? null : _sendOtp, child: const Text('Send OTP')),
                  ],
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 16),
                  TextField(controller: _otp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'OTP')),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email ID (optional)'),
                ),
                const SizedBox(height: 16),
                TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPassword,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm Password'),
                ),
                const SizedBox(height: 20),
                Text('Service Category', style: Theme.of(context).textTheme.titleMedium),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Select a category'),
                  value: _selectedCategoryId,
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (id) {
                    if (id != null) _selectCategory(id);
                  },
                ),
                if (_selectedCategoryId != null) ...[
                  const SizedBox(height: 12),
                  Text('Sub-service(s) Offered', style: Theme.of(context).textTheme.titleMedium),
                  for (final s in _subServices)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.name),
                      value: _selectedSubServiceIds.contains(s.id),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _selectedSubServiceIds.add(s.id);
                        } else {
                          _selectedSubServiceIds.remove(s.id);
                        }
                      }),
                    ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _yearsExperience,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Years of Experience (optional)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _coverageRadiusKm,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Service Area / Coverage Radius (km)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _idProofUrl,
                  decoration: const InputDecoration(labelText: 'ID Proof (Aadhaar / PAN) — document link'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bankOrUpiDetails,
                  decoration: const InputDecoration(labelText: 'Bank / UPI Details (optional, can be added later)'),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _acceptedTerms,
                  onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                  title: const Text('I accept the Terms & Conditions'),
                ),
                const SizedBox(height: 8),
                PrimaryCta(onPressed: _busy ? null : _createAccount, child: const Text('Create Account')),
              ],
            ),
    );
  }
}
