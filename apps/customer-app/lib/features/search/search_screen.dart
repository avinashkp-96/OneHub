import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../requirements/post_requirement_screen.dart';

// docx 4.2 "Search", opened from the dashboard's search bar. Type a service,
// category or provider name; suggestions appear after two letters and the
// search runs on submit or on picking a suggestion. Filters (category,
// minimum rating, maximum starting price) and sort (top rated or lowest
// price) are in a sheet behind the filter button.
//
// Results come in two lists from GET /search: services, and providers with
// their matching services and starting price. Either opens Post a
// Requirement for that service, so the customer can describe the job and pick
// providers from there.
//
// Recent searches are kept in memory for this session ([recentSearches]);
// nothing persists them yet. Distance ("nearest first", radius) and "available
// now" are not offered: provider locations and online status are not stored.

/// The last few searches, newest first, for this session only.
final recentSearches = ValueNotifier<List<String>>(const []);
const _maxRecent = 5;

void rememberSearch(String query) {
  final q = query.trim();
  if (q.isEmpty) return;
  recentSearches.value = [
    q,
    ...recentSearches.value.where((r) => r.toLowerCase() != q.toLowerCase()),
  ].take(_maxRecent).toList();
}

class SearchFilters {
  final String? categoryId;
  final String? categoryName;
  final double? minRating;
  final int? maxPrice;
  final bool sortByPrice;
  const SearchFilters({
    this.categoryId,
    this.categoryName,
    this.minRating,
    this.maxPrice,
    this.sortByPrice = false,
  });

  bool get isEmpty =>
      categoryId == null && minRating == null && maxPrice == null && !sortByPrice;

  Map<String, String> get query => {
        if (categoryId != null) 'categoryId': categoryId!,
        if (minRating != null) 'minRating': '$minRating',
        if (maxPrice != null) 'maxPrice': '$maxPrice',
        if (sortByPrice) 'sort': 'price',
      };

  /// Short labels for the active filters, shown under the search box.
  List<String> get labels => [
        if (categoryName != null) categoryName!,
        if (minRating != null) '${_ratingLabel(minRating!)}★ and up',
        if (maxPrice != null) 'Up to ₹$maxPrice',
        if (sortByPrice) 'Lowest price first',
      ];
}

String _ratingLabel(double r) => r == r.roundToDouble() ? '${r.toInt()}' : '$r';

class ServiceHit {
  final String id;
  final String name;
  final String categoryName;
  final double? minPrice;
  final double? maxPrice;
  const ServiceHit(
      this.id, this.name, this.categoryName, this.minPrice, this.maxPrice);

  factory ServiceHit.fromJson(Map<String, dynamic> j) => ServiceHit(
        j['id'] as String,
        j['name'] as String,
        j['categoryName'] as String,
        (j['suggestedMinPrice'] as num?)?.toDouble(),
        (j['suggestedMaxPrice'] as num?)?.toDouble(),
      );
}

class ProviderHit {
  final String id;
  final String name;
  final double averageRating;
  final int ratingCount;
  final bool certified;
  final List<String> categories;
  final List<({String id, String name})> services;
  final double? startingPrice;
  const ProviderHit(this.id, this.name, this.averageRating, this.ratingCount,
      this.certified, this.categories, this.services, this.startingPrice);

  factory ProviderHit.fromJson(Map<String, dynamic> j) => ProviderHit(
        j['id'] as String,
        j['name'] as String,
        (j['averageRating'] as num).toDouble(),
        (j['ratingCount'] as num).toInt(),
        j['certified'] as bool? ?? false,
        (j['categories'] as List).cast<String>(),
        [
          for (final s in j['services'] as List)
            (
              id: (s as Map<String, dynamic>)['id'] as String,
              name: s['name'] as String
            )
        ],
        (j['startingPrice'] as num?)?.toDouble(),
      );
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  SearchFilters _filters = const SearchFilters();
  List<String> _suggestions = [];
  List<ServiceHit>? _services; // null until the first search
  List<ProviderHit> _providers = [];
  bool _searching = false;
  String? _error;
  int _request = 0; // ignores answers to searches that were superseded

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    setState(() {}); // shows or hides the clear button
    if (text.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _suggest(text));
  }

  Future<void> _suggest(String text) async {
    try {
      final q = Uri.encodeQueryComponent(text.trim());
      final list = (await api.get('/search/suggest?q=$q') as List).cast<String>();
      if (!mounted || text != _controller.text) return;
      setState(() => _suggestions = list);
    } catch (_) {
      if (mounted) setState(() => _suggestions = []);
    }
  }

  Future<void> _search([String? text]) async {
    if (text != null) _controller.text = text;
    final q = _controller.text.trim();
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    rememberSearch(q);
    final request = ++_request;
    setState(() {
      _suggestions = [];
      _searching = true;
      _error = null;
    });
    try {
      final params = {if (q.isNotEmpty) 'q': q, ..._filters.query};
      final query = Uri(queryParameters: params).query;
      final json = await api.get(query.isEmpty ? '/search' : '/search?$query')
          as Map<String, dynamic>;
      if (!mounted || request != _request) return;
      setState(() {
        _services = [
          for (final s in json['services'] as List)
            ServiceHit.fromJson(s as Map<String, dynamic>)
        ];
        _providers = [
          for (final p in json['providers'] as List)
            ProviderHit.fromJson(p as Map<String, dynamic>)
        ];
        _searching = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = 'Search failed: $e';
        _searching = false;
      });
    }
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    setState(() {
      _suggestions = [];
      _services = null;
      _providers = [];
      _error = null;
    });
  }

  Future<void> _openFilters() async {
    final picked = await showModalBottomSheet<SearchFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: _filters),
    );
    if (picked == null || !mounted) return;
    setState(() => _filters = picked);
    if (_services != null) _search();
  }

  void _openService(String subServiceId) => Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => PostRequirementScreen(subServiceId: subServiceId)));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    Widget section(String text) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Text(text,
              style: OneHubTextStyles.pageHeading(textPrimary)
                  .copyWith(fontSize: 18)),
        );

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Search')),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('search-field'),
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: 'Search electrician, plumber...',
                        prefixIcon: Icon(OneHubIcons.search,
                            size: 18, color: textMuted),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                // OneHubIcons has no close glyph; a plus
                                // turned 45 degrees reads as one.
                                icon: Transform.rotate(
                                    angle: 0.785398,
                                    child: Icon(OneHubIcons.plus,
                                        size: 18, color: textMuted)),
                                onPressed: _clear),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.outlined(
                    key: const Key('filter-button'),
                    tooltip: 'Filters',
                    onPressed: _openFilters,
                    icon: Icon(OneHubIcons.filter,
                        size: 18,
                        color: _filters.isEmpty
                            ? textMuted
                            : OneHubColors.primary),
                  ),
                ],
              ),
              if (_filters.labels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final l in _filters.labels)
                      TintedBadge(label: l, color: OneHubColors.primary, pill: true),
                  ],
                ),
              ],
              if (_suggestions.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 10),
                  child: Column(
                    children: [
                      for (final s in _suggestions)
                        ListTile(
                          dense: true,
                          leading: Icon(OneHubIcons.search,
                              size: 16, color: textMuted),
                          title: Text(s,
                              style: OneHubTextStyles.bodyText(textPrimary)),
                          onTap: () => _search(s),
                        ),
                    ],
                  ),
                ),
              if (_searching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(_error!,
                      style: TextStyle(color: context.statusDanger)),
                )
              else if (_services == null)
                ValueListenableBuilder<List<String>>(
                  valueListenable: recentSearches,
                  builder: (_, recent, __) => recent.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 22),
                          child: Text(
                              'Search by service, like "fan installation", or by a provider\'s name.',
                              style: OneHubTextStyles.bodyText(textSecondary)),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: section('Recent searches')),
                                TextButton(
                                  onPressed: () =>
                                      recentSearches.value = const [],
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                            for (final r in recent)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(OneHubIcons.calendar,
                                    size: 16, color: textMuted),
                                title: Text(r,
                                    style:
                                        OneHubTextStyles.bodyText(textPrimary)),
                                onTap: () => _search(r),
                              ),
                          ],
                        ),
                )
              else if (_services!.isEmpty && _providers.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No providers found nearby.',
                          style: OneHubTextStyles.bodyText(textPrimary)
                              .copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                          'Try a different word, or remove some filters to widen your search.',
                          style: OneHubTextStyles.bodyText(textSecondary)),
                    ],
                  ),
                )
              else ...[
                if (_services!.isNotEmpty) ...[
                  section('Services'),
                  for (final s in _services!)
                    _ServiceCard(hit: s, onTap: () => _openService(s.id)),
                ],
                if (_providers.isNotEmpty) ...[
                  section('Providers'),
                  for (final p in _providers)
                    _ProviderCard(
                        hit: p, onTap: () => _openService(p.services.first.id)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _rupees(double v) => '₹${v.toStringAsFixed(0)}';

class _ServiceCard extends StatelessWidget {
  final ServiceHit hit;
  final VoidCallback onTap;
  const _ServiceCard({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final price = hit.minPrice != null && hit.maxPrice != null
        ? 'TYPICALLY ${_rupees(hit.minPrice!)}–${_rupees(hit.maxPrice!)}'
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hit.name,
                        style: OneHubTextStyles.bodyText(textPrimary)
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(hit.categoryName,
                        style: OneHubTextStyles.fieldLabel(textMuted)
                            .copyWith(letterSpacing: 0)),
                    if (price != null) ...[
                      const SizedBox(height: 8),
                      TintedBadge(label: price, color: OneHubColors.primary),
                    ],
                  ],
                ),
              ),
              Icon(OneHubIcons.chevronRight, size: 16, color: textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final ProviderHit hit;
  final VoidCallback onTap;
  const _ProviderCard({required this.hit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final rating = hit.ratingCount == 0
        ? 'New'
        : '${hit.averageRating.toStringAsFixed(1)}★ (${hit.ratingCount})';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(hit.name,
                        style: OneHubTextStyles.bodyText(textPrimary)
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (hit.certified) ...[
                    TintedBadge(
                        label: 'CERTIFIED', color: context.statusSuccess),
                    const SizedBox(width: 8),
                  ],
                  Text(rating,
                      style: OneHubTextStyles.bodyText(OneHubColors.warning)
                          .copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Text(hit.categories.join(', '),
                  style: OneHubTextStyles.fieldLabel(textMuted)
                      .copyWith(letterSpacing: 0)),
              const SizedBox(height: 8),
              Text(hit.services.map((s) => s.name).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: OneHubTextStyles.bodyText(textSecondary)
                      .copyWith(fontSize: 13)),
              if (hit.startingPrice != null) ...[
                const SizedBox(height: 8),
                TintedBadge(
                    label: 'FROM ${_rupees(hit.startingPrice!)}',
                    color: OneHubColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final SearchFilters initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _categoryId = widget.initial.categoryId;
  late String? _categoryName = widget.initial.categoryName;
  late double? _minRating = widget.initial.minRating;
  late int? _maxPrice = widget.initial.maxPrice;
  late bool _sortByPrice = widget.initial.sortByPrice;
  List<ServiceCategory> _categories = [];

  static const _ratings = [3.0, 4.0, 4.5];
  static const _prices = [300, 500, 1000, 2000];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final json = await api.get('/categories') as List;
      if (!mounted) return;
      setState(() => _categories = [
            for (final c in json)
              ServiceCategory.fromJson(c as Map<String, dynamic>)
          ]);
    } catch (_) {
      // The other filters still work without the category list.
    }
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(onTap),
      );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(text, style: OneHubTextStyles.fieldLabel(textMuted)),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(OneHubTheme.pageMargin, 16,
            OneHubTheme.pageMargin, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters',
                style: OneHubTextStyles.pageHeading(textPrimary)
                    .copyWith(fontSize: 20)),
            heading('CATEGORY'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip('Any', _categoryId == null, () {
                _categoryId = null;
                _categoryName = null;
              }),
              for (final c in _categories)
                _chip(c.name, _categoryId == c.id, () {
                  _categoryId = c.id;
                  _categoryName = c.name;
                }),
            ]),
            heading('MINIMUM RATING'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip('Any', _minRating == null, () => _minRating = null),
              for (final r in _ratings)
                _chip('${_ratingLabel(r)}★ and up', _minRating == r,
                    () => _minRating = r),
            ]),
            heading('STARTING PRICE'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip('Any', _maxPrice == null, () => _maxPrice = null),
              for (final p in _prices)
                _chip('Up to ₹$p', _maxPrice == p, () => _maxPrice = p),
            ]),
            heading('SORT BY'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip('Top rated', !_sortByPrice, () => _sortByPrice = false),
              _chip('Lowest price', _sortByPrice, () => _sortByPrice = true),
            ]),
            const SizedBox(height: 10),
            Text(
                'Distance and "available now" filters need provider locations and online status, which are not saved yet.',
                style: OneHubTextStyles.fieldLabel(textMuted)
                    .copyWith(letterSpacing: 0, fontSize: 12)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const SearchFilters()),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PrimaryCta(
                    onPressed: () => Navigator.of(context).pop(SearchFilters(
                      categoryId: _categoryId,
                      categoryName: _categoryName,
                      minRating: _minRating,
                      maxPrice: _maxPrice,
                      sortByPrice: _sortByPrice,
                    )),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
