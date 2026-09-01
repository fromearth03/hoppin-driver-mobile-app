import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../data/models/driver_today.dart';

/// Earnings, trips and time online for the day so far.
///
/// A driver working a shift otherwise has nothing on Home telling them how it
/// is going — the Earnings tab answers the week, not the last four hours.
///
/// The design labels the middle column "Earnings" twice; it plainly means
/// trips, which is what the value under it is.
class TodayTiles extends StatelessWidget {
  final DriverToday today;

  const TodayTiles({super.key, required this.today});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Summary",
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 20),
            // No vertical rules between the columns: at this size they read
            // as stray strokes rather than structure — the even thirds and
            // the shared baseline do the separating on their own.
            Row(
              children: [
                Expanded(child: _tile('Earnings', today.earnings.format())),
                const SizedBox(width: 16),
                Expanded(child: _tile('Trips', '${today.tripCount}')),
                const SizedBox(width: 16),
                Expanded(child: _tile('Online Time', today.onlineLabel)),
              ],
            ),
          ],
        ),
      );

  Widget _tile(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 15, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      );
}
