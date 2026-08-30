import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../logic/stats_controller.dart';
import 'widgets/penalties_section.dart';
import 'widgets/stat_tile.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statsControllerProvider);
    final controller = ref.read(statsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          final stats = state.stats;
          if (stats == null && state.error != null) {
            return AppErrorState(
              error: state.error!,
              onRetry: controller.refresh,
            );
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            // A fixed two-section page, not a feed. A lazy ListView would
            // leave the penalties section unbuilt below the fold — and that
            // section is the one a driver opens this screen to read.
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        StatTile(
                          icon: Icons.directions_car_outlined,
                          tint: AppColors.primary,
                          label: 'Trips completed',
                          // A count, never a currency figure.
                          value: '${stats?.tripsCompleted ?? 0}',
                        ),
                        StatTile(
                          icon: Icons.star_outline,
                          tint: AppColors.warning,
                          label: 'Rating',
                          value:
                              stats?.averageRating?.toStringAsFixed(1) ?? '—',
                          note: (stats?.ratingCount ?? 0) > 0
                              ? '${stats!.ratingCount} reviews'
                              : 'No reviews yet',
                        ),
                        StatTile(
                          icon: Icons.check_circle_outline,
                          tint: AppColors.positive,
                          label: 'Acceptance rate',
                          value:
                              stats?.ratePercent(stats.acceptanceRate) ?? '—',
                        ),
                        StatTile(
                          icon: Icons.cancel_outlined,
                          tint: AppColors.negative,
                          label: 'Cancellations',
                          value: '${stats?.tripsCancelled ?? 0}',
                          note: 'Trips you cancelled',
                        ),
                      ],
                    ),
                  ),
                  PenaltiesSection(
                    penalties: state.penalties,
                    appeals: state.appeals,
                    onAppeal: (penalty) =>
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Appealing "${penalty.displayTitle}"',
                            ),
                          ),
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
