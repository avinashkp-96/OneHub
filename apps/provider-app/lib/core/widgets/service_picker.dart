import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import 'service_tile.dart';

/// Pick every category you work in, then the services you offer in each.
/// Used by signup step 2 and Business details. [categoryIds] and [serviceIds]
/// belong to the parent and are changed in place; [onChanged] runs after each
/// change. Unpicking a category drops its services. Each picked category's
/// services are loaded from GET /categories/:id/sub-services once.
class ServicePicker extends StatefulWidget {
  final ApiClient api;
  final List<ServiceCategory> categories;
  final Set<String> categoryIds;
  final Set<String> serviceIds;
  final bool enabled;
  final VoidCallback? onChanged;

  /// Builds a section heading ("Categories", "Electrician services").
  final Widget Function(String text) heading;

  const ServicePicker({
    super.key,
    required this.api,
    required this.categories,
    required this.categoryIds,
    required this.serviceIds,
    required this.heading,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<ServicePicker> createState() => _ServicePickerState();
}

class _ServicePickerState extends State<ServicePicker> {
  final Map<String, List<SubService>> _services = {};
  final Map<String, String> _loadErrors = {};

  @override
  void initState() {
    super.initState();
    for (final id in widget.categoryIds) {
      _load(id);
    }
  }

  Future<void> _load(String categoryId) async {
    if (_services.containsKey(categoryId)) return;
    setState(() => _loadErrors.remove(categoryId));
    try {
      final json =
          await widget.api.get('/categories/$categoryId/sub-services') as List;
      if (!mounted) return;
      setState(() => _services[categoryId] = [
            for (final s in json) SubService.fromJson(s as Map<String, dynamic>)
          ]);
    } catch (e) {
      if (mounted) {
        setState(() => _loadErrors[categoryId] =
            'Could not load these services. ${userMessage(e)}');
      }
    }
  }

  void _toggleCategory(String id) {
    setState(() {
      if (widget.categoryIds.remove(id)) {
        for (final s in _services[id] ?? const <SubService>[]) {
          widget.serviceIds.remove(s.id);
        }
      } else {
        widget.categoryIds.add(id);
      }
    });
    if (widget.categoryIds.contains(id)) _load(id);
    widget.onChanged?.call();
  }

  void _toggleService(String id) {
    setState(() {
      if (!widget.serviceIds.remove(id)) widget.serviceIds.add(id);
    });
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final warning = context.statusWarning;
    final hint = OneHubTextStyles.bodyText(textMuted).copyWith(fontSize: 13);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.heading('Categories'),
        Text('Pick every category you work in.', style: hint),
        const SizedBox(height: 12),
        if (widget.categories.isEmpty)
          Text('No service categories are available yet.',
              style: OneHubTextStyles.bodyText(warning))
        else
          ServiceGrid(
            children: [
              for (final c in widget.categories)
                ServiceTile(
                  key: Key('category-${c.id}'),
                  label: c.name,
                  imageUrl: c.iconUrl,
                  fallbackIcon: OneHubIcons.category,
                  selected: widget.categoryIds.contains(c.id),
                  onTap: widget.enabled ? () => _toggleCategory(c.id) : null,
                ),
            ],
          ),
        for (final c in widget.categories)
          if (widget.categoryIds.contains(c.id)) ...[
            const SizedBox(height: 24),
            widget.heading('${c.name} services'),
            Text('Select all that apply.', style: hint),
            const SizedBox(height: 12),
            if (_loadErrors[c.id] != null)
              Text(_loadErrors[c.id]!,
                  style: TextStyle(color: context.statusDanger))
            else if (_services[c.id] == null)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()))
            else if (_services[c.id]!.isEmpty)
              Text('No services listed under this category yet.',
                  style: OneHubTextStyles.bodyText(warning))
            else
              ServiceGrid(
                children: [
                  for (final s in _services[c.id]!)
                    ServiceTile(
                      key: Key('service-${s.id}'),
                      label: s.name,
                      fallbackIcon: OneHubIcons.work,
                      selected: widget.serviceIds.contains(s.id),
                      onTap: widget.enabled ? () => _toggleService(s.id) : null,
                    ),
                ],
              ),
          ],
      ],
    );
  }
}
