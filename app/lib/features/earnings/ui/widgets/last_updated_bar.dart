import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

/// The strip above the totals saying when the figures were last fetched.
///
/// The time is the client's own — nothing on the summary endpoint reports a
/// generation time — so this answers "is what I'm looking at current?" and
/// nothing more. The design's green "Up to date" is shown while the fetch is
/// recent; past that it says how stale the numbers are rather than claiming
/// freshness it cannot vouch for.
class LastUpdatedBar extends StatelessWidget {
  final DateTime? fetchedAt;

  /// How long a fetch counts as current. Earnings settle on trip completion,
  /// so a few minutes old is genuinely up to date.
  static const freshFor = Duration(minutes: 5);

  const LastUpdatedBar({super.key, required this.fetchedAt});

  @override
  Widget build(BuildContext context) {
    final at = fetchedAt;
    final age = at == null ? null : DateTime.now().difference(at);
    final fresh = age != null && age < freshFor;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_toggle_off,
              size: 20, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              at == null
                  ? 'Last updated: —'
                  : 'Last updated: ${_stamp(at)}',
              style: AppText.body,
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fresh ? AppColors.positive : AppColors.warning,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fresh ? 'Up to date' : _staleness(age),
            style: AppText.body.copyWith(
              color: fresh ? AppColors.positive : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  static String _stamp(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final time = DateFormat('hh:mm a').format(local);
    return sameDay ? 'Today, $time' : '${DateFormat('d MMM').format(local)}, $time';
  }

  static String _staleness(Duration? age) {
    if (age == null) return 'Not loaded';
    if (age.inHours >= 1) return '${age.inHours}h ago';
    return '${age.inMinutes}m ago';
  }
}
