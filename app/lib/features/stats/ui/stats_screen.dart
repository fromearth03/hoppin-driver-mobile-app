import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/nav/app_shell.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/async_view.dart';
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
      body: AsyncView(
        value: async,
        loading: () => const SkeletonList(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state, _) {
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
            // Content sits at its natural height. Forcing it to fill the
            // viewport only moved the empty ground from between the sections
            // to below them — a short page is short, and padding it out does
            // not make it look fuller.
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
                      // 🔴 The extent is the tile's real content height, not a
                      // round number. It was 118pt scaled by the font setting,
                      // which reserved more row than the tiles filled and left
                      // a visible band of dead ground between this grid and
                      // the section beneath it.
                      //
                      // Now: badge (38) + gap (10) + label + value + an
                      // optional third line, plus the card's own padding. The
                      // text parts scale with the system font; the badge and
                      // the padding do not, so only the text is multiplied.
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: StatTile.heightFor(context),
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
