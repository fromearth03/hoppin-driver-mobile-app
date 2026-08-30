import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/driver_trip.dart';

/// One trip. Cancelled trips are present but visually demoted: they are a
/// third of all activity and they drive the cancellation-rate stat, so
/// hiding them would leave a driver unable to check their own record — but
/// they should not compete with work that earned money.
class TripRow extends StatelessWidget {
  final DriverTrip trip;

  const TripRow({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final cancelled = trip.isCancelled;
    final labelColour =
        cancelled ? AppColors.textSecondary : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (cancelled)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.block,
                      size: 15, color: AppColors.textSecondary),
                ),
              Expanded(
                child: Text(trip.pickupLabel,
                    style: AppText.body.copyWith(color: labelColour),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '→ ${trip.dropoffLabel}',
            style: AppText.body.copyWith(
              color: labelColour,
              decoration: cancelled ? TextDecoration.lineThrough : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(_meta(), style: AppText.caption)),
              Text(_amount(), style: _amountStyle()),
            ],
          ),
          // Who cancelled stands on its own line rather than being joined
          // into the meta string: it is the first question a driver asks of
          // a cancelled trip, and it must be readable as one statement.
          if (trip.cancelledByLabel != null) ...[
            const SizedBox(height: 4),
            Text(trip.cancelledByLabel!, style: AppText.caption),
          ],
          if (trip.cancelReason != null) ...[
            const SizedBox(height: 4),
            Text(trip.cancelReason!, style: AppText.caption),
          ],
        ],
      ),
    );
  }

  String _meta() {
    final parts = <String>[
      if (trip.ref != null) trip.ref!,
      if (trip.completedAt != null)
        DateFormat('HH:mm').format(trip.completedAt!.toLocal()),
      if (!trip.isCancelled && trip.distanceMiles != null)
        '${trip.distanceMiles!.toStringAsFixed(1)} mi',
    ];
    return parts.join(' · ');
  }

  /// A cancellation that cost nothing shows an em dash. "£0.00" would read
  /// as a charge of zero rather than no charge at all.
  String _amount() {
    if (trip.isCancelled) {
      return trip.penalty.isZero
          ? '—'
          : trip.penalty.format().replaceFirst('£', '−£');
    }
    return trip.earnings.formatSigned();
  }

  TextStyle _amountStyle() => AppText.body.copyWith(
        fontWeight: FontWeight.w600,
        color: trip.isCancelled
            ? (trip.penalty.isZero
                ? AppColors.textSecondary
                : AppColors.negative)
            : AppColors.positive,
      );
}
