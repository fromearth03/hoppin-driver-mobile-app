import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../earnings/data/models/ride_earnings.dart';
import '../data/models/driver_trip.dart';
import '../logic/trip_detail_controller.dart';

/// One past trip: where it went, what it paid, and — when it was cancelled —
/// who cancelled it and what that cost.
///
/// The rider is deliberately absent. Their identity lives on
/// `/rides/:id/rider-context`, which refuses a ride that has ended, and a
/// driver has no reason to hold a passenger's name after the job is done.
class TripDetailScreen extends ConsumerWidget {
  final DriverTrip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripDetailControllerProvider(trip.id));

    return Scaffold(
      appBar: AppBar(title: Text(trip.ref ?? 'Trip')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(),
          const SizedBox(height: 16),
          _journey(),
          const SizedBox(height: 16),
          async.when(
            loading: () => const AppLoading(),
            error: (e, _) => const SizedBox.shrink(),
            data: (state) {
              final earnings = state.earnings;
              if (earnings == null) {
                return state.error == null
                    ? const SizedBox.shrink()
                    : AppErrorState(
                        error: state.error!,
                        onRetry: () => ref.invalidate(
                            tripDetailControllerProvider(trip.id)),
                      );
              }
              return _breakdown(earnings);
            },
          ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _header() => _card(children: [
        Text(
          trip.isCancelled ? 'Cancelled' : 'Completed',
          style: AppText.heading.copyWith(
            color: trip.isCancelled ? AppColors.negative : AppColors.positive,
          ),
        ),
        if (trip.completedAt != null) ...[
          const SizedBox(height: 4),
          Text(DateFormat('EEE d MMM, HH:mm').format(trip.completedAt!),
              style: AppText.caption),
        ],
        if (trip.cancelledByLabel != null) ...[
          const SizedBox(height: 8),
          Text(trip.cancelledByLabel!, style: AppText.body),
        ],
        // The server's own prose for why. Never paraphrased: a driver
        // disputing a cancellation needs the wording support will see.
        if (trip.cancelReason != null && trip.cancelReason!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(trip.cancelReason!, style: AppText.caption),
        ],
        if (!trip.penalty.isZero) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Penalty', style: AppText.body),
              Text('-${trip.penalty.format()}',
                  style: AppText.body.copyWith(color: AppColors.negative)),
            ],
          ),
        ],
      ]);

  Widget _journey() => _card(children: [
        const Text('Journey', style: AppText.heading),
        const SizedBox(height: 12),
        _stop(Icons.trip_origin, trip.pickupLabel),
        const SizedBox(height: 8),
        _stop(Icons.place_outlined, trip.dropoffLabel),
        if (trip.distanceMiles != null) ...[
          const SizedBox(height: 12),
          Text('${trip.distanceMiles!.toStringAsFixed(1)} miles',
              style: AppText.caption),
        ],
      ]);

  Widget _stop(IconData icon, String label) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label.isEmpty ? 'Not recorded' : label,
              style: AppText.body,
            ),
          ),
        ],
      );

  /// Only the lines that carry a value, plus Net. Settlement writes tax and
  /// penalty as literal zero on this endpoint, so rendering them would
  /// assert a treatment nobody signed off.
  Widget _breakdown(RideEarnings earnings) => _card(children: [
        const Text('Earnings', style: AppText.heading),
        const SizedBox(height: 12),
        ...earnings.lines.map(
          (line) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(line.label, style: AppText.body),
                Text(line.amount.format(), style: AppText.body),
              ],
            ),
          ),
        ),
      ]);
}
