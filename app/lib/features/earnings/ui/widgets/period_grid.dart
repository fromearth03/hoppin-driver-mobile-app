import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/ride_earnings.dart';
import '../../logic/earnings_controller.dart';
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
    return GestureDetector(
      onTap: () => onSelect(period),
      child: EarningsCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
        outlined: period == selected,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 26, color: AppColors.textPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      // A period that failed to load shows a dash. A zero
                      // would read as "you earned nothing", which is a
                      // different and much worse claim.
                      summary?.net.format() ?? '—',
                      style: AppText.title.copyWith(fontSize: 24),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(labels[period]!, style: AppText.heading.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            Text(_range(period, summary), style: AppText.caption),
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

/// The named periods in the order the grid lays them out. Re-exported so a
/// caller does not have to know the controller's constant.
const gridPeriods = earningsPeriods;
