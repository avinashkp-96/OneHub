import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import 'sub_service_list_screen.dart';

// docx 4.1 "Service Categories — Horizontal/grid list of category icons
// (Electrician, Plumber, etc.) — tap to browse sub-services".
class CategoryGridScreen extends StatefulWidget {
  const CategoryGridScreen({super.key});

  @override
  State<CategoryGridScreen> createState() => _CategoryGridScreenState();
}

class _CategoryGridScreenState extends State<CategoryGridScreen> {
  List<ServiceCategory> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await api.get('/categories') as List;
      setState(() {
        _categories = json.map((c) => ServiceCategory.fromJson(c as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load categories: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse services')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [Text(_error!, style: TextStyle(color: context.statusDanger))],
                    )
                  : _categories.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(16),
                          children: const [Text('No service categories are available yet.')],
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) => _CategoryTile(
                            category: _categories[index],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SubServiceListScreen(category: _categories[index])),
                            ),
                          ),
                        ),
            ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback onTap;
  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        // Matches OneHubTheme's cardTheme radius so the ink ripple doesn't
        // poke past the card's rounded corners.
        borderRadius: BorderRadius.circular(OneHubTheme.radiusFormCard),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                foregroundImage: category.iconUrl != null ? NetworkImage(category.iconUrl!) : null,
                child: category.iconUrl == null
                    ? Icon(OneHubIcons.category, color: colorScheme.onPrimaryContainer)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
