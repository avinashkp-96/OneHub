import 'package:flutter/material.dart';
import 'package:onehub_shared/onehub_shared.dart';
import '../../core/api.dart';

// docx 5.9 "Ratings Received": average, number of ratings, the 5★-1★
// distribution, and each customer's review. Reached from the Profile screen.
// Same shell as the other provider screens (PageGlow, page title in the
// AppBar, one GlowCard summary, bordered cards for the list). Loads
// GET /ratings/mine, which shows reviewers by first name and last initial.

class Review {
  final String id;
  final int stars;
  final String? feedback;
  final DateTime createdAt;
  final String customerName;
  const Review(
      this.id, this.stars, this.feedback, this.createdAt, this.customerName);

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        json['id'] as String,
        (json['stars'] as num).toInt(),
        json['feedback'] as String?,
        DateTime.parse(json['createdAt'] as String).toLocal(),
        json['customerName'] as String,
      );
}

class RatingsSummary {
  final double average;
  final int count;
  final Map<int, int> distribution; // stars -> number of ratings
  final List<Review> reviews;
  const RatingsSummary(this.average, this.count, this.distribution, this.reviews);

  factory RatingsSummary.fromJson(Map<String, dynamic> json) {
    final dist = json['distribution'] as Map<String, dynamic>;
    return RatingsSummary(
      (json['averageRating'] as num).toDouble(),
      (json['ratingCount'] as num).toInt(),
      {for (var s = 5; s >= 1; s--) s: (dist['$s'] as num? ?? 0).toInt()},
      [
        for (final r in json['reviews'] as List)
          Review.fromJson(r as Map<String, dynamic>)
      ],
    );
  }
}

/// Takes an optional [client], like the other provider screens, so tests can
/// use a fake API; [clock] fixes "time ago" labels in tests.
class RatingsScreen extends StatefulWidget {
  final ApiClient? client;
  final DateTime Function()? clock;
  const RatingsScreen({super.key, this.client, this.clock});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  ApiClient get _api => widget.client ?? api;

  RatingsSummary? _summary;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await _api.get('/ratings/mine') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _summary = RatingsSummary.fromJson(json);
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your ratings: $e';
        _loading = false;
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
    final s = _summary;
    final now = (widget.clock ?? DateTime.now)();

    return Scaffold(
      appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          title: const Text('Ratings')),
      body: PageGlow(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: OneHubTheme.pageMargin, vertical: 8),
              children: [
                Text('What customers say about your work.',
                    style: OneHubTextStyles.bodyText(textSecondary)),
                const SizedBox(height: OneHubTheme.sectionGap),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (s == null)
                  Text(_error ?? '',
                      style: TextStyle(color: context.statusDanger))
                else ...[
                  _SummaryCard(summary: s),
                  const SizedBox(height: 26),
                  Text('Reviews',
                      style: OneHubTextStyles.pageHeading(textPrimary)
                          .copyWith(fontSize: 18)),
                  const SizedBox(height: 12),
                  if (s.reviews.isEmpty)
                    Text(
                        'No ratings yet. They appear here after customers rate a completed job.',
                        style: OneHubTextStyles.bodyText(context.statusWarning))
                  else
                    for (final r in s.reviews)
                      _ReviewCard(
                          review: r,
                          timeLabel: relativeTimeLabel(r.createdAt, now)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final double value; // 0-5, rounded to the nearest whole star
  final double size;
  const _Stars({required this.value, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final empty =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final filled = value.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= filled ? OneHubIcons.starFilled : OneHubIcons.starOutline,
              size: size,
              color: i <= filled ? OneHubColors.warning : empty),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final RatingsSummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final track =
        dark ? OneHubColors.cardBorderDark : OneHubColors.cardBorderLight;
    final s = summary;
    final most = s.distribution.values.fold<int>(0, (a, b) => a > b ? a : b);

    return GlowCard(
      child: Padding(
        padding: const EdgeInsets.all(OneHubTheme.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.count == 0 ? '–' : s.average.toStringAsFixed(1),
                    key: const Key('ratings-average'),
                    style: OneHubTextStyles.pageHeading(textPrimary)
                        .copyWith(fontSize: 40)),
                const SizedBox(height: 4),
                _Stars(value: s.average),
                const SizedBox(height: 6),
                Text(s.count == 1 ? '1 rating' : '${s.count} ratings',
                    style: OneHubTextStyles.fieldLabel(textMuted)
                        .copyWith(letterSpacing: 0)),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: [
                  for (var stars = 5; stars >= 1; stars--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text('$stars★',
                                style: OneHubTextStyles.fieldLabel(textMuted)
                                    .copyWith(letterSpacing: 0)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                key: Key('ratings-bar-$stars'),
                                minHeight: 6,
                                value: most == 0
                                    ? 0
                                    : s.distribution[stars]! / most,
                                backgroundColor: track,
                                color: OneHubColors.warning,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 18,
                            child: Text('${s.distribution[stars]}',
                                textAlign: TextAlign.right,
                                style: OneHubTextStyles.fieldLabel(textMuted)
                                    .copyWith(letterSpacing: 0)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  final String timeLabel;
  const _ReviewCard({required this.review, required this.timeLabel});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        dark ? OneHubColors.textPrimaryDark : OneHubColors.textPrimaryLight;
    final textSecondary =
        dark ? OneHubColors.textSecondaryDark : OneHubColors.textSecondaryLight;
    final textMuted =
        dark ? OneHubColors.textMutedDark : OneHubColors.textMutedLight;
    final feedback = review.feedback?.trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Stars(value: review.stars.toDouble(), size: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(review.customerName,
                      style: OneHubTextStyles.bodyText(textPrimary)
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
                Text(timeLabel,
                    style: OneHubTextStyles.fieldLabel(textMuted)
                        .copyWith(letterSpacing: 0, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              feedback.isEmpty ? 'No written feedback.' : feedback,
              style: OneHubTextStyles.bodyText(
                      feedback.isEmpty ? textMuted : textSecondary)
                  .copyWith(
                      fontStyle:
                          feedback.isEmpty ? FontStyle.italic : FontStyle.normal),
            ),
          ],
        ),
      ),
    );
  }
}
