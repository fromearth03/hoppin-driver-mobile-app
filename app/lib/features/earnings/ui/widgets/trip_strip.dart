import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../trips/data/models/driver_trip.dart';
import 'earnings_card.dart';
import 'period_grid.dart';

/// The trips behind the selected period's total: where each went, when, and
/// what it paid. Three at a time, with the full history a tap away.
class TripStrip extends StatelessWidget {
  final String period;
  final List<DriverTrip> trips;
  final VoidCallback onViewAll;

  /// The design shows three rows before the section ends.
  static const _max = 3;

  const TripStrip({
    super.key,
    required this.period,
    required this.trips,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final shown = trips.take(_max).toList();
    return EarningsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EarningsSectionTitle(
            '${PeriodGrid.possessives[period]} Trips',
            trailing: GestureDetector(
              onTap: onViewAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View All Trips',
                      style: AppText.body.copyWith(fontSize: 14)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward,
                      size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No trips in this period.',
                  style: AppText.bodySecondary),
            )
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.border),
              _row(shown[i]),
            ],
        ],
      ),
    );
  }

  Widget _row(DriverTrip trip) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.info,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.place, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.pickupLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(trip.dropoffLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading.copyWith(fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(trip.earnings.format(),
                      maxLines: 1,
                      style: AppText.heading.copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(_when(trip.completedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
      );

  static String _when(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final time = DateFormat('hh:mm a').format(local);
    return sameDay
        ? 'Today at $time'
        : '${DateFormat('d MMM').format(local)} at $time';
  }
}
