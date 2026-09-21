import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';

// docx 4.3 — Post a Requirement. `subServiceId` is carried over from category
// browsing (docx 4.1 "Service Categories" -> sub-service list), which isn't
// built yet, so this screen currently requires it to be passed in directly.
class PostRequirementScreen extends StatefulWidget {
  final String subServiceId;
  const PostRequirementScreen({super.key, required this.subServiceId});

  @override
  State<PostRequirementScreen> createState() => _PostRequirementScreenState();
}

class _PostRequirementScreenState extends State<PostRequirementScreen> {
  final _description = TextEditingController();
  DateTime? _preferredAt;
  List<ProviderSummary> _providers = [];
  final Set<String> _selectedProviderIds = {};
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final json = await api.get('/providers?subServiceId=${widget.subServiceId}') as List;
      setState(() {
        _providers = json.map((p) => ProviderSummary.fromJson(p as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load providers: $e';
        _loading = false;
      });
    }
  }

  Future<void> _sendRequest() async {
    if (_description.text.trim().isEmpty || _selectedProviderIds.isEmpty) {
      setState(() => _error = 'Describe the work and select at least one provider.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await api.post('/requirements', {
        'subServiceId': widget.subServiceId,
        'description': _description.text.trim(),
        if (_preferredAt != null) 'preferredAt': _preferredAt!.toIso8601String(),
        'providerIds': _selectedProviderIds.toList(),
      }, auth: true);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Could not send the request: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Describe your requirement')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                TextField(
                  controller: _description,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'What do you need done?', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_preferredAt == null ? 'Preferred date/time (optional)' : _preferredAt.toString()),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                      initialDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _preferredAt = picked);
                  },
                ),
                const SizedBox(height: 20),
                Text('Select provider(s)', style: Theme.of(context).textTheme.titleMedium),
                if (_providers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No providers found nearby. Try widening your search.'),
                  ),
                for (final p in _providers)
                  CheckboxListTile(
                    title: Text(p.name),
                    subtitle: Text('${p.averageRating.toStringAsFixed(1)}★${p.certified ? ' · Certified' : ''}'),
                    value: _selectedProviderIds.contains(p.id),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selectedProviderIds.add(p.id);
                      } else {
                        _selectedProviderIds.remove(p.id);
                      }
                    }),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _sending ? null : _sendRequest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _sending ? const CircularProgressIndicator() : const Text('Send Request'),
                  ),
                ),
              ],
            ),
    );
  }
}
