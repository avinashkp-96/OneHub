import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../requirements/post_requirement_screen.dart';

// docx 4.1 "tap to browse sub-services" -> 4.3 "Category / Sub-service" field,
// pre-filled from here when the customer taps through to post a requirement.
class SubServiceListScreen extends StatefulWidget {
  final ServiceCategory category;
  const SubServiceListScreen({super.key, required this.category});

  @override
  State<SubServiceListScreen> createState() => _SubServiceListScreenState();
}

class _SubServiceListScreenState extends State<SubServiceListScreen> {
  List<SubService> _subServices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await api.get('/categories/${widget.category.id}/sub-services') as List;
      setState(() {
        _subServices = json.map((s) => SubService.fromJson(s as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load services: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) Text(_error!, style: TextStyle(color: context.statusDanger)),
                  if (_subServices.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No services listed under this category yet.'),
                    ),
                  for (final s in _subServices)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(s.name),
                        subtitle: _priceRangeLabel(s) == null ? null : Text(_priceRangeLabel(s)!),
                        trailing: const Icon(OneHubIcons.chevronRight),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PostRequirementScreen(subServiceId: s.id)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String? _priceRangeLabel(SubService s) {
    if (s.suggestedMinPrice == null || s.suggestedMaxPrice == null) return null;
    return 'Typically ₹${s.suggestedMinPrice!.toStringAsFixed(0)}–₹${s.suggestedMaxPrice!.toStringAsFixed(0)}';
  }
}
