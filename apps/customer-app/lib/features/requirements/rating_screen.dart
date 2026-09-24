import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';

// docx 4.6 — Ratings & Feedback. Shown after a job is marked complete.
class RatingScreen extends StatefulWidget {
  final String requirementId;
  final String providerId;
  const RatingScreen({super.key, required this.requirementId, required this.providerId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _stars = 0;
  final _feedback = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_stars == 0) {
      setState(() => _error = 'Select a star rating.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.post('/ratings', {
        'requirementId': widget.requirementId,
        'providerId': widget.providerId,
        'stars': _stars,
        if (_feedback.text.trim().isNotEmpty) 'feedback': _feedback.text.trim(),
      }, auth: true);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Could not submit your rating: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate this service')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: TextStyle(color: context.statusDanger)),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    iconSize: 36,
                    icon: Icon(
                      i <= _stars ? OneHubIcons.starFilled : OneHubIcons.starOutline,
                      color: context.statusWarning,
                    ),
                    onPressed: () => setState(() => _stars = i),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _feedback,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Written feedback (optional)'),
            ),
            const SizedBox(height: 20),
            PrimaryCta(onPressed: _busy ? null : _submit, child: const Text('Submit Rating')),
          ],
        ),
      ),
    );
  }
}
