import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/nav/app_shell.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../data/models/driver_promotion.dart';
import '../logic/earnings_controller.dart';
import 'widgets/balance_cards.dart';
import 'widgets/breakdown_card.dart';
import 'widgets/earnings_card.dart';
import 'widgets/last_updated_bar.dart';
import 'widgets/payout_row.dart';
import 'widgets/period_grid.dart';
import 'widgets/report_card.dart';
import 'widgets/trip_strip.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(earningsControllerProvider);
    final controller = ref.read(earningsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        // Opens AppShell's drawer, not this Scaffold's — this one has none.
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () => AppShell.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.textPrimary),
            onPressed: () => context.go(Routes.settings),
          ),
        ],
      ),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          if (state.summaries.isEmpty && state.error != null) {
            return AppErrorState(
                error: state.error!, onRetry: controller.refresh);
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            // Not a lazy ListView: the grid, breakdown and balance tiles form
            // a tall first section, and a lazy list would never build the
            // payout rows or the report card beneath them — they would be
            // absent from the tree, not merely scrolled off.
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LastUpdatedBar(fetchedAt: state.fetchedAt),
                  PeriodGrid(
                    summaries: state.summaries,
                    selected: state.period,
                    onSelect: controller.setPeriod,
                  ),
                  BreakdownCard(period: state.period, summary: state.summary),
                  if (state.wallet != null)
                    BalanceCards(
                      wallet: state.wallet!,
                      onViewStatement: () => context.push(Routes.statement),
                    ),
                  TripStrip(
                    period: state.period,
                    trips: state.recentTrips,
                    onViewAll: () => context.push(Routes.trips),
                  ),
                  if (state.promotions.isNotEmpty) _bonuses(state.promotions),
                  if ((state.wallet?.recentPayouts ?? []).isNotEmpty)
                    _payouts(state),
                  const ReportCard(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Live bonus campaigns. Only campaigns that pay the driver reach here —
  /// the endpoint also carries rider-discount promos, and listing one on an
  /// earnings screen would promise money that is not coming.
  Widget _bonuses(List<DriverPromotion> promotions) => EarningsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EarningsSectionTitle('Bonuses Available'),
            const SizedBox(height: 8),
            for (final promo in promotions) _promotionRow(promo),
          ],
        ),
      );

  Widget _promotionRow(DriverPromotion promo) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(promo.title,
                      style: AppText.heading.copyWith(fontSize: 16)),
                  if (promo.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(promo.description, style: AppText.caption),
                  ],
                  if (promo.expiresAt != null) ...[
                    const SizedBox(height: 2),
                    Text('Ends ${_shortDate(promo.expiresAt!)}',
                        style: AppText.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('+${promo.bonus!.format()}',
                style: AppText.heading
                    .copyWith(fontSize: 16, color: AppColors.positive)),
          ],
        ),
      );

  /// Payout history, read-only.
  ///
  /// The design puts a "Payouts" card above this one — Next Payout, a
  /// countdown chip, the destination bank's masked number, a progress bar
  /// and a payout threshold. None of it has a source: the wallet endpoint
  /// returns balances and past batches only, there is no scheduled-payout,
  /// threshold or bank-account endpoint anywhere in the service, and the
  /// masked account number does not exist in the app's data at all. The
  /// design's "Payouts Methods" card is missing for the same reason —
  /// payout setup is Stripe-hosted and the app never learns the account.
  /// Both are omitted rather than filled with plausible numbers.
  Widget _payouts(EarningsState state) => EarningsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EarningsSectionTitle('Payouts History'),
            const SizedBox(height: 6),
            for (var i = 0; i < state.wallet!.recentPayouts.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.border),
              PayoutRow(payout: state.wallet!.recentPayouts[i]),
            ],
            const SizedBox(height: 6),
            const Text('Payouts are issued by your operator.',
                style: AppText.caption),
          ],
        ),
      );

  static String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
