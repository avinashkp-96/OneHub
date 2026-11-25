import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../profile/profile_state.dart';
import '../requirements/post_requirement_screen.dart';
import '../search/search_screen.dart';

// Providers near the customer, from GET /search with no keyword: every active
// provider with their services, nearest first from the address Home is set
// to (customerLocation). Without one it falls back to best rated first.
// Tapping a provider opens a request for one of their services with that
// provider already selected.

/// Every active provider, nearest first when the customer has a location.
Future<List<ProviderHit>> loadNearbyProviders() async {
  final near = customerLocation.value;
  final json = await api.get(
          near == null ? '/search' : '/search?sort=distance&${near.query}')
      as Map<String, dynamic>;
  return [
    for (final p in json['providers'] as List)
      ProviderHit.fromJson(p as Map<String, dynamic>)
  ];
}

/// Opens Post a Requirement for [hit]'s first matching service, with [hit]
/// already ticked.
Future<void> openProviderRequest(BuildContext context, ProviderHit hit) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PostRequirementScreen(
            subServiceId: hit.services.first.id,
            preselectedProviderId: hit.id)));

/// One line under the heading: where distances are measured from.
String nearbyCaption(SavedLocation? near) => near == null
    ? 'Best rated first. Set your address on Home to see who is nearest.'
    : 'Nearest first, from ${near.city}.';

/// "See all" from the Home page's Nearby providers section.
class NearbyProvidersScreen extends StatefulWidget {
  const NearbyProvidersScreen({super.key});

  @override
  State<NearbyProvidersScreen> createState() => _NearbyProvidersScreenState();
}

class _NearbyProvidersScreenState extends State<NearbyProvidersScreen> {
  List<ProviderHit>? _providers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await loadNearbyProviders();
      if (mounted) setState(() => _providers = list);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load providers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final providers = _providers;
    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Nearby providers')),
      body: PageGlow(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: OneHubTheme.pageMargin, vertical: 8),
              children: [
                Text(nearbyCaption(customerLocation.value),
                    style: OneHubTextStyles.bodyText(textSecondary)),
                const SizedBox(height: OneHubTheme.sectionGap),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: context.statusDanger))
                else if (providers == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (providers.isEmpty)
                  Text('No providers yet.',
                      style: OneHubTextStyles.bodyText(textSecondary))
                else
                  for (final p in providers)
                    ProviderHitCard(
                        hit: p, onTap: () => openProviderRequest(context, p)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
