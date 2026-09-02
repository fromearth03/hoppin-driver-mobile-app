import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/driver_trip.dart';

/// One trip. Cancelled trips are present but visually demoted: they are a
/// third of all activity and they drive the cancellation-rate stat, so
/// hiding them would leave a driver unable to check their own record — but
/// they should not compete with work that earned money.
///
/// The design puts a rider star rating on every row. `/drivers/me/trips`
/// carries no rider rating, and the rider-context endpoint refuses a ride
/// that has ended, so there is nothing to render there.
class TripRow extends StatelessWidget {
  final DriverTrip trip;
  final VoidCallback? onTap;

  const TripRow({super.key, required this.trip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cancelled = trip.isCancelled;
    final labelColour =
        cancelled ? AppColors.textSecondary : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stop(
                  Icons.location_on,
                  trip.pickupLabel,
                  labelColour,
                  strike: false,
                ),
                // The leg between the two stops, drawn where the route runs:
                // inset to sit under the pin, so the pair reads as one
                // journey rather than two stacked addresses.
                const Padding(
                  padding: EdgeInsets.only(left: 9, top: 4, bottom: 4),
                  child: SizedBox(
                    height: 14,
                    child: VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _stop(
                        Icons.outlined_flag,
                        trip.dropoffLabel,
                        labelColour,
                        strike: cancelled,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      // An em dash, not "£0.00": a cancelled trip did not
                      // earn nothing, it never earned.
                      trip.earnings.isZero
                          ? '—'
                          : '+${trip.earnings.format()}',
                      style: AppText.body.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        // Money earned is green wherever it appears in the
                        // app. On a list that mixes completed work with
                        // cancellations, it is also what tells the two apart
                        // at a glance.
                        color: trip.earnings.isZero
                            ? AppColors.textSecondary
                            : AppColors.positive,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      trip.completedAt == null
                          ? 'Time not recorded'
                          : DateFormat('h:mm a').format(trip.completedAt!),
                      style: AppText.caption.copyWith(fontSize: 14),
                    ),
                    // The reference is what a driver quotes to support, so
                    // it stays on the row rather than behind the detail.
                    if (trip.ref != null) ...[
                      const SizedBox(width: 10),
                      // The reference is what a driver reads out to support,
                      // so it gets a chip of its own rather than running into
                      // the time beside it.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(trip.ref!,
                            style: AppText.caption.copyWith(fontSize: 13)),
                      ),
                    ],
                    const Spacer(),
                    // A penalty is the one thing on a row a driver will
                    // dispute, so it is never hidden behind the detail view.
                    // The attribution is the flexible party: it ellipsizes
                    // before the time, reference or amount lose a pixel.
                    if (trip.cancelledByLabel != null)
                      Flexible(
                        child: Text(
                          trip.cancelledByLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(fontSize: 14),
                        ),
                      ),
                    if (!trip.penalty.isZero) ...[
                      const SizedBox(width: 10),
                      Text(
                        '−${trip.penalty.format()}',
                        style: AppText.caption.copyWith(
                          fontSize: 14,
                          color: AppColors.negative,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stop(
    IconData icon,
    String label,
    Color colour, {
    required bool strike,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label.isEmpty ? 'Not recorded' : label,
              style: AppText.body.copyWith(
                fontSize: 16,
                color: colour,
                decoration: strike ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}
