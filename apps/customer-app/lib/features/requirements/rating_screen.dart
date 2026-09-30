import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';
import '../../core/widgets/field_label.dart';

// docx 4.6 — Ratings & Feedback. Shown after a job is marked complete.
// Restyled to match the current OneHub design system (no new reference —
// applied on request): PageGlow behind the screen, a single GlowCard
// holding the whole form (star picker + feedback field, the one primary
// form card on this screen), and a back-only AppBar + in-body heading to
// match the pattern set on post_requirement_screen.dart.
class RatingScreen extends StatefulWidget {
  final String requirementId;
  final String providerId;
  const RatingScreen(
      {super.key, required this.requirementId, required this.providerId});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _stars = 0;
  final _feedback = TextEditingController();
  bool _busy = false;
  String? _error;

  static const _starLabels = ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'];

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
      await api.post(
          '/ratings',
          {
            'requirementId': widget.requirementId,
            'providerId': widget.providerId,
            'stars': _stars,
            if (_feedback.text.trim().isNotEmpty)
              'feedback': _feedback.text.trim(),
          },
          auth: true);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Could not submit your rating: $e');
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
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop())),
      body: PageGlow(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: OneHubTheme.pageMargin, vertical: 8),
            children: [
              Text('Rate this service',
                  style: OneHubTextStyles.pageHeading(textPrimary)
                      .copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text(
                'Your feedback helps other customers pick the right provider.',
                style: OneHubTextStyles.bodyText(textSecondary),
              ),
              const SizedBox(height: OneHubTheme.sectionGap),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!,
                      style: TextStyle(color: context.statusDanger)),
                ),
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(OneHubTheme.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 1; i <= 5; i++)
                                IconButton(
                                  iconSize: 36,
                                  icon: Icon(
                                    i <= _stars
                                        ? OneHubIcons.starFilled
                                        : OneHubIcons.starOutline,
                                    color: context.statusWarning,
                                  ),
                                  onPressed: () => setState(() => _stars = i),
                                ),
                            ],
                          ),
                          if (_stars > 0)
                            Text(_starLabels[_stars],
                                style: OneHubTextStyles.bodyText(textMuted)),
                        ],
                      ),
                      const SizedBox(height: OneHubTheme.sectionGap),
                      const FieldLabel('WRITTEN FEEDBACK (OPTIONAL)',
                          icon: OneHubIcons.edit),
                      const SizedBox(height: OneHubTheme.gapFieldInternals),
                      TextField(
                        controller: _feedback,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            hintText: 'What stood out about this job?'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryCta(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Rating'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
