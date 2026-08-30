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
                        dayLabel(trip.completedAt ?? DateTime.now()) !=
                            dayLabel(state.trips[index - 1].completedAt ??
                                DateTime.now());
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                                dayLabel(trip.completedAt ?? DateTime.now()),
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
