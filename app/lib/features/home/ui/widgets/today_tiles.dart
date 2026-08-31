import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/driver_today.dart';

/// Earnings, trips and time online for the day so far.
///
/// A driver working a shift otherwise has nothing on Home telling them how it
/// is going — the Earnings tab answers the week, not the last four hours.
class TodayTiles extends StatelessWidget {
  final DriverToday today;

  const TodayTiles({super.key, required this.today});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _tile('Today', today.earnings.format()),
            _divider(),
            // Plural only when it should be: "1 trips" reads as a bug.
            _tile('Trips', '${today.tripCount}'),
            _divider(),
            _tile('Online', today.onlineLabel),
          ],
        ),
      );

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: AppColors.border,
      );

  Widget _tile(String label, String value) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppText.heading),
          const SizedBox(height: 4),
          Text(label, style: AppText.caption),
        ],
      );
}
