import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/nav/app_shell.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../logic/stats_controller.dart';
import 'appeal_sheet.dart';
import 'widgets/penalties_section.dart';
import '../data/models/driver_stats.dart';
import 'widgets/period_card.dart';
import 'widgets/stat_tile.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statsControllerProvider);
    final controller = ref.read(statsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        // The period governs every figure below, so it sits with the title
        // rather than taking the first row of the page.
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: PeriodCard(
                compact: true,
                period: async.value?.period ?? StatsPeriod.week,
                onChanged: controller.setPeriod,
              ),
            ),
          ),
        ],
      ),
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
              padding:
                  const EdgeInsets.only(bottom: AppShell.bottomClearance),
              child: Column(
                children: [
                  // The window the service actually resolved. The picker in
                  // the bar names the period; this says which days it landed
                  // on, which is the app's only honest claim about what the
                  // figures below cover.
                  if (stats?.from != null && stats?.to != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          PeriodCard.rangeLabel(stats!.from!, stats.to!),
                          style: AppText.bodySecondary,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // Fixed tile height: the content (two-line label,
                      // value, note) is constant in text lines, so deriving
                      // height from width via an aspect ratio overflowed on
                      // narrow phones and left dead space on wide ones. The
                      // extent scales with the system font setting — 118
                      // logical pixels only fits the lines at scale 1.0.
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 118 *
                            MediaQuery.textScalerOf(context).scale(14) /
                            14,
                      ),
                      children: [
                        StatTile(
                          icon: Icons.directions_car_filled_outlined,
                          tint: AppColors.statPurple,
                          label: 'Total Trips',
                          // The design renders this as "£ 1247.00". It is a
                          // trip count, not money — no currency symbol.
                          value: '${stats?.tripsCompleted ?? 0}',
                        ),
                        StatTile(
                          icon: Icons.star_outline_rounded,
                          tint: AppColors.info,
                          label: 'Rating',
                          value:
                              stats?.averageRating?.toStringAsFixed(1) ?? '—',
                          stars: stats?.averageRating,
                          note: (stats?.ratingCount ?? 0) > 0
                              ? '${stats!.ratingCount} reviews'
                              : 'No reviews yet',
                        ),
                        StatTile(
                          icon: Icons.check_rounded,
                          tint: AppColors.positive,
                          label: 'Acceptance Rate',
                          value:
                              stats?.ratePercent(stats.acceptanceRate) ?? '—',
                        ),
                        StatTile(
                          icon: Icons.close_rounded,
                          tint: AppColors.statRed,
                          label: 'Cancellation Rate',
                          value:
                              stats?.ratePercent(stats.cancellationRate) ?? '—',
                          // Rider cancels, admin force-cancels and watchdog
                          // timeouts are excluded server-side, so the driver
                          // needs to know the number is theirs alone. The
                          // design's "+0.5%" trend line has no source — the
                          // endpoint returns no previous period to compare
                          // against — so the count sits here instead.
                          note: '${stats?.tripsCancelled ?? 0} you cancelled',
                        ),
                      ],
                    ),
                  ),
                  PenaltiesSection(
                    penalties: state.penalties,
                    appeals: state.appeals,
                    onAppeal: (penalty) async {
                      final filed = await AppealSheet.show(context, penalty);
                      if (filed) await controller.refresh();
                    },
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
