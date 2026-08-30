import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../logic/earnings_controller.dart';
import 'widgets/payout_row.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  static const _periods = {
    'today': 'Today',
    'week': 'Week',
    'month': 'Month',
    'all': 'All time',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(earningsControllerProvider);
    final controller = ref.read(earningsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          if (state.summary == null && state.error != null) {
            return AppErrorState(
                error: state.error!, onRetry: controller.refresh);
          }
          return RefreshIndicator(
            onRefresh: controller.refresh,
            // Not a lazy ListView: the period bar, total card and balance
            // tile form a tall first section, and a lazy list would never
            // build the payout rows or the note beneath them — they would
            // be absent from the tree, not merely scrolled off.
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _periodBar(state.period, controller),
                _totalCard(state),
                _balanceTile(context, state),
                if ((state.wallet?.recentPayouts ?? []).isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text('Payouts', style: AppText.heading),
                  ),
                  ...state.wallet!.recentPayouts
                      .map((p) => PayoutRow(payout: p)),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Payouts are issued by your operator.',
                      style: AppText.caption,
                    ),
                  ),
                ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _periodBar(String active, EarningsController controller) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: _periods.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: active == e.key,
                      onSelected: (_) => controller.setPeriod(e.key),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ))
              .toList(),
        ),
      );

  Widget _totalCard(EarningsState state) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You earned', style: AppText.caption),
            const SizedBox(height: 4),
            Text(state.summary?.net.format() ?? '—', style: AppText.money),
            const SizedBox(height: 4),
            Text('${state.summary?.tripCount ?? 0} trips',
                style: AppText.caption),
            // The headline is take-home. Without the deductions beside it a
            // driver cannot tell a quiet week from a week eaten by charges,
            // so show what came off - and only what actually applied.
            ...?state.summary?.deductions.map(
              (line) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(line.label, style: AppText.caption),
                    Text('-${line.amount.format()}', style: AppText.caption),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  /// The balance links to the Statement, which is the one place every
  /// individual credit and charge is itemised in the server's own words.
  Widget _balanceTile(BuildContext context, EarningsState state) {
    final balance = state.wallet?.availableBalance;
    if (balance == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ListTile(
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(balance.isNegative ? 'You owe' : 'Your balance',
            style: AppText.body),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              balance.format(),
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: balance.isNegative
                    ? AppColors.negative
                    : AppColors.textPrimary,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
        onTap: () => context.push(Routes.statement),
      ),
    );
  }
}
