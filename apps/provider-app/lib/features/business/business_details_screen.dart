import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';
import '../../core/widgets/service_tile.dart';
import 'business_details.dart';

// docx 5.2 "Profile & Service Mapping": edit the services offered,
// experience and coverage radius after signup. Reached from the Business card
// on Profile. Same shell as the other provider screens (PageGlow, page title in the AppBar, one GlowCard), and the same category and
// service tiles as signup step 2.
//
// Real endpoints: GET /providers/me to load, GET /categories and
// /categories/:id/sub-services for the choices, PATCH /providers/me to save.
// The API only accepts services from one category, matching signup.

/// Takes an optional [client], like the other provider screens, so tests can
/// use a fake API. Pops with `true` after a successful save.
class BusinessDetailsScreen extends StatefulWidget {
  final ApiClient? client;
  const BusinessDetailsScreen({super.key, this.client});

  @override
  State<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen> {
  ApiClient get _api => widget.client ?? api;

  final _experience = TextEditingController();
  final _coverage = TextEditingController();

  BusinessDetails? _saved;
  List<ServiceCategory> _categories = [];
  List<SubService> _subServices = [];
  String? _categoryId;
  final Set<String> _selectedIds = {};

  bool _loading = true;
  bool _loadingSubServices = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _experience.dispose();
    _coverage.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final saved = BusinessDetails.fromJson(
          await _api.get('/providers/me') as Map<String, dynamic>);
      final categories = (await _api.get('/categories') as List)
          .map((c) => ServiceCategory.fromJson(c as Map<String, dynamic>))
          .toList();
      final subServices = saved.categoryId == null
          ? <SubService>[]
          : await _fetchSubServices(saved.categoryId!);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _categories = categories;
        _categoryId = saved.categoryId;
        _subServices = subServices;
        _selectedIds.addAll(saved.services.map((s) => s.id));
        _experience.text = saved.yearsExperience?.toString() ?? '';
        _coverage.text = formatKm(saved.coverageRadiusKm);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your business details: $e';
        _loading = false;
      });
    }
  }

  Future<List<SubService>> _fetchSubServices(String categoryId) async =>
      (await _api.get('/categories/$categoryId/sub-services') as List)
          .map((s) => SubService.fromJson(s as Map<String, dynamic>))
          .toList();

  Future<void> _selectCategory(String categoryId) async {
    if (categoryId == _categoryId) return;
    setState(() {
      _categoryId = categoryId;
      _selectedIds.clear();
      // Going back to the saved category brings its saved services back.
      if (categoryId == _saved?.categoryId) {
        _selectedIds.addAll(_saved!.services.map((s) => s.id));
      }
      _subServices = [];
      _loadingSubServices = true;
      _error = null;
    });
    try {
      final subServices = await _fetchSubServices(categoryId);
      if (!mounted || categoryId != _categoryId) return;
      setState(() {
        _subServices = subServices;
        _loadingSubServices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load services: $e';
        _loadingSubServices = false;
      });
    }
  }

  void _toggleService(String id) => setState(() {
        if (!_selectedIds.remove(id)) _selectedIds.add(id);
        _error = null;
      });

  Future<void> _save() async {
    final experienceText = _experience.text.trim();
    final experience =
        experienceText.isEmpty ? null : int.tryParse(experienceText);
    final coverage = double.tryParse(_coverage.text.trim());

    String? problem;
    if (experienceText.isNotEmpty &&
        (experience == null || experience < 0 || experience > 60)) {
      problem = 'Experience must be a whole number from 0 to 60.';
    } else if (coverage == null || coverage < 1 || coverage > 100) {
      problem = 'Coverage must be between 1 and 100 km.';
    } else if (_selectedIds.isEmpty) {
      problem = 'Pick at least one service you offer.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.patch(
          '/providers/me',
          {
            'yearsExperience': experience,
            'coverageRadiusKm': coverage,
            'subServiceIds': _selectedIds.toList(),
          },
          auth: true);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final bar = successSnackBar(context, 'Business details saved.');
      Navigator.of(context).pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(bar);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not save your business details: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final warning = context.statusWarning;

    Widget section(String text) => Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 12),
          child: Text(text,
              style: OneHubTextStyles.pageHeading(textPrimary)
                  .copyWith(fontSize: 18)),
        );

    final errorText = _error == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_error!, style: TextStyle(color: context.statusDanger)),
          );

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Business details')),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('What you offer and how far you travel.',
                  style: OneHubTextStyles.bodyText(textSecondary)),
              const SizedBox(height: OneHubTheme.sectionGap),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_saved == null)
                errorText
              else ...[
                GlowCard(
                  child: Padding(
                    padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FieldLabel('YEARS OF EXPERIENCE (optional)',
                            icon: OneHubIcons.calendar),
                        const SizedBox(height: OneHubTheme.gapFieldInternals),
                        TextField(
                          controller: _experience,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: 'e.g. 5'),
                        ),
                        const SizedBox(height: OneHubTheme.sectionGap),
                        const FieldLabel('COVERAGE RADIUS (km)',
                            required: true, icon: OneHubIcons.location),
                        const SizedBox(height: OneHubTheme.gapFieldInternals),
                        TextField(
                          controller: _coverage,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(hintText: 'e.g. 10'),
                        ),
                      ],
                    ),
                  ),
                ),
                section('Category'),
                if (_categories.isEmpty)
                  Text('No service categories are available yet.',
                      style: OneHubTextStyles.bodyText(warning))
                else
                  ServiceGrid(
                    children: [
                      for (final c in _categories)
                        ServiceTile(
                          label: c.name,
                          imageUrl: c.iconUrl,
                          fallbackIcon: OneHubIcons.category,
                          selected: c.id == _categoryId,
                          onTap: _saving ? null : () => _selectCategory(c.id),
                        ),
                    ],
                  ),
                if (_categoryId != null) ...[
                  section('Services you offer'),
                  if (_loadingSubServices)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()))
                  else if (_subServices.isEmpty)
                    Text('No services listed under this category yet.',
                        style: OneHubTextStyles.bodyText(warning))
                  else
                    ServiceGrid(
                      children: [
                        for (final s in _subServices)
                          ServiceTile(
                            label: s.name,
                            fallbackIcon: OneHubIcons.work,
                            selected: _selectedIds.contains(s.id),
                            onTap: _saving ? null : () => _toggleService(s.id),
                          ),
                      ],
                    ),
                ],
                errorText,
                const SizedBox(height: 32),
                PrimaryCta(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save changes'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
