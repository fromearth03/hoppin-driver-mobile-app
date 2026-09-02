import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/ride_earnings.dart';
import 'earnings_card.dart';

/// The 2x2 grid of period totals: today, this week, this month, all time.
///
/// Selecting a card is what drives the breakdown beneath it, which is why
/// the design outlines exactly one of the four.
class PeriodGrid extends StatelessWidget {
  final Map<String, EarningsSummary> summaries;
  final String selected;
  final ValueChanged<String> onSelect;

  const PeriodGrid({
    super.key,
    required this.summaries,
    required this.selected,
    required this.onSelect,
  });

  static const labels = {
    'today': "Today's Earnings",
    'week': 'This Week',
    'month': 'This Month',
    'all': 'All Time',
  };

  /// One colour per period, so the four blocks are told apart by more than
  /// their captions. Today is the green one — it is the figure a driver
  /// checks most, and the one that grows while they work.
  static const _accents = {
    'today': AppColors.positive,
    'week': AppColors.primaryLight,
    'month': AppColors.warning,
    'all': AppColors.textSecondary,
  };

  static const _icons = {
    'today': Icons.today_outlined,
    'week': Icons.date_range_outlined,
    'month': Icons.calendar_month_outlined,
    'all': Icons.workspace_premium_outlined,
  };

  /// The same periods phrased to carry a following noun, so a section reads
  /// "Today's Breakdown" and "This Week's Trips" rather than gluing the
  /// card's own caption onto a heading.
  static const possessives = {
    'today': "Today's",
    'week': "This Week's",
    'month': "This Month's",
    'all': 'All Time',
  };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          children: [
            _row('today', 'week'),
            const SizedBox(height: 16),
            _row('month', 'all'),
          ],
        ),
      );

  /// Two cards side by side at the same height. A period whose date range
  /// wraps to two lines would otherwise leave its neighbour short.
  Widget _row(String left, String right) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _cell(left)),
            const SizedBox(width: 16),
            Expanded(child: _cell(right)),
          ],
        ),
      );

  Widget _cell(String period) {
    final summary = summaries[period];
    final accent = _accents[period]!;
    final isSelected = period == selected;
    return GestureDetector(
      onTap: () => onSelect(period),
      child: EarningsCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        outlined: isSelected,
        accent: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 30,
                  width: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(_icons[period], size: 17, color: accent),
                ),
                const Spacer(),
                // The selected period drives the breakdown below, so it says
                // so rather than relying on the border alone.
                if (isSelected)
                  Icon(Icons.check_circle, size: 17, color: accent),
              ],
            ),
            const SizedBox(height: 12),
            // The money wraps rather than shrinking to fit. Scaling it down
            // was making a four-figure week read smaller than a quiet day
            // beside it.
            Text(
              // A period that failed to load shows a dash. A zero would read
              // as "you earned nothing", which is a different and much worse
              // claim.
              summary?.net.format() ?? '—',
              maxLines: 2,
              style: AppText.title.copyWith(fontSize: 23, height: 1.1),
            ),
            const SizedBox(height: 8),
            Text(
              labels[period]!,
              maxLines: 2,
              style: AppText.heading.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: accent.withValues(alpha: 0.22)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(_range(period, summary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption),
                ),
                if (summary != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    // What the money was earned from: the figure alone does
                    // not say whether it was a busy day or a lucky one.
                    '${summary.tripCount} ${summary.tripCount == 1 ? 'trip' : 'trips'}',
                    style: AppText.caption.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The window the service reported for this period, in its own bounds.
  /// `to` is exclusive server-side, so the last day shown steps back one.
  static String _range(String period, EarningsSummary? summary) {
    if (period == 'all') return 'Since joining';
    final from = summary?.from;
    final to = summary?.to;
    if (from == null) return '';
    if (period == 'today') return DateFormat('d MMM, yyyy').format(from);
    final last = (to ?? from).subtract(const Duration(days: 1));
    return '${DateFormat('d MMM').format(from)} - ${DateFormat('d MMM').format(last)}';
  }
}
