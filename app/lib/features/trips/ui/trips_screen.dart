import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/cursor_list.dart';
import '../data/models/driver_trip.dart';
import '../logic/trips_controller.dart';
import 'widgets/trip_row.dart';

/// The driver's own record of work done. Deliberately carries no totals —
/// that is the Earnings screen's job, and two screens computing the same
/// figure are two screens that can disagree.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  static const _filters = {
    TripFilter.all: 'All',
    TripFilter.completed: 'Completed',
    TripFilter.cancelled: 'Cancelled',
  };

  /// Groups a trip whose date the server did not send under an explicit
  /// "Undated" heading. Substituting today would tell a driver checking last
  /// week's cancellations that they happened this morning.
  static String dayLabelFor(DateTime? when) =>
      when == null ? 'Undated' : dayLabel(when);

  static String dayLabel(DateTime when) {
    final now = DateTime.now();
    final date = DateTime(when.year, when.month, when.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(date).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return DateFormat('EEE d MMM').format(when);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripsControllerProvider);
    final controller = ref.read(tripsControllerProvider.notifier);
    final filter = async.value?.filter ?? TripFilter.all;

    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: Column(
        children: [
          _filterBar(filter, controller),
          _dateBar(context, async.value, controller),
          Expanded(
            child: async.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('$e', style: AppText.body)),
              data: (state) {
                if (state.trips.isEmpty && state.error != null) {
                  return AppErrorState(
                      error: state.error!, onRetry: controller.refresh);
                }
                return CursorList<DriverTrip>(
                  items: state.trips,
                  hasMore: state.hasMore,
                  isLoadingMore: state.isLoadingMore,
                  onLoadMore: controller.loadMore,
                  onRefresh: controller.refresh,
                  emptyState: AppEmptyState(
                    icon: Icons.route_outlined,
                    title: switch (state.filter) {
                      TripFilter.cancelled => 'No cancelled trips',
                      TripFilter.completed => 'No completed trips yet',
                      TripFilter.all => 'No trips yet',
                    },
                  ),
                  itemBuilder: (context, trip) {
                    final index = state.trips.indexOf(trip);
                    final showHeader = index == 0 ||
                        dayLabelFor(trip.completedAt) !=
                            dayLabelFor(
                                state.trips[index - 1].completedAt);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                                dayLabelFor(trip.completedAt),
                                style: AppText.caption),
                          ),
                        TripRow(trip: trip),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The chosen range, or an invitation to pick one. A whole second row of
  /// chrome would be wasted on a driver who never filters by date, so this
  /// stays one line until they use it.
  Widget _dateBar(
    BuildContext context,
    TripsState? state,
    TripsController controller,
  ) {
    final from = state?.from;
    final to = state?.to;
    final label = switch ((from, to)) {
      (null, null) => 'Any date',
      (final f?, null) => 'From ${_shortDate(f)}',
      (null, final t?) => 'Until ${_shortDate(t)}',
      (final f?, final t?) => '${_shortDate(f)} - ${_shortDate(t)}',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          ActionChip(
            key: const Key('date_range'),
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(label),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                // A driver cannot have driven in the future, and the
                // platform predates this.
                firstDate: DateTime(2024),
                lastDate: now,
                initialDateRange: from != null && to != null
                    ? DateTimeRange(start: from, end: to)
                    : null,
              );
              if (picked != null) {
                await controller.setDateRange(picked.start, picked.end);
              }
            },
          ),
          if (state?.hasDateRange ?? false) ...[
            const SizedBox(width: 8),
            TextButton(
              key: const Key('clear_date_range'),
              onPressed: () => controller.setDateRange(null, null),
              child: const Text('Clear'),
            ),
          ],
        ],
      ),
    );
  }

  static String _shortDate(DateTime d) => DateFormat('d MMM').format(d);

  Widget _filterBar(TripFilter active, TripsController controller) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: _filters.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: active == e.key,
                      onSelected: (_) => controller.setFilter(e.key),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ))
              .toList(),
        ),
      );
}
