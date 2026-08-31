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
import 'trip_detail_screen.dart';
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
                        TripRow(
                          trip: trip,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TripDetailScreen(trip: trip),
                            ),
                          ),
                        ),
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

  /// The range card the design puts at the top of the list. A driver
  /// checking last month's work reaches for this before anything else.
  Widget _dateBar(
    BuildContext context,
    TripsState? state,
    TripsController controller,
  ) {
    final from = state?.from;
    final to = state?.to;
    final title = switch ((from, to)) {
      (null, null) => 'All time',
      (final f?, null) => 'Since ${_shortDate(f)}',
      (null, final t?) => 'Until ${_shortDate(t)}',
      (final f?, final t?) => '${_shortDate(f)} - ${_shortDate(t)}',
    };
    final subtitle = state?.hasDateRange ?? false
        ? '${state!.trips.length} trips'
        : 'Tap to choose a date range';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const Key('date_range'),
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: context,
              // A driver cannot have driven in the future, and the platform
              // does not predate this.
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 30, color: AppColors.textPrimary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.body.copyWith(
                            fontSize: 19, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: AppText.caption.copyWith(fontSize: 14)),
                    ],
                  ),
                ),
                if (state?.hasDateRange ?? false)
                  IconButton(
                    key: const Key('clear_date_range'),
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => controller.setDateRange(null, null),
                  )
                else
                  const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _shortDate(DateTime d) => DateFormat('d MMM').format(d);

  Widget _filterBar(TripFilter active, TripsController controller) =>
      // Scrolls sideways rather than overflowing: three chips fit a phone,
      // but a narrow window (or a longer translation someday) must degrade
      // to a scroll, not a RenderFlex error.
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
