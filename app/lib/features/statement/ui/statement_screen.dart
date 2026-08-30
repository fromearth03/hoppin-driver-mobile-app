import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/cursor_list.dart';
import '../data/models/ledger_entry.dart';
import '../logic/statement_controller.dart';
import 'widgets/ledger_row.dart';

/// Both money directions in one place. A negative balance is what the driver
/// owes; a positive one is what the company owes them. The figure is stated
/// plainly — never softened, and never accompanied by a claim about how it
/// will be collected.
class StatementScreen extends ConsumerWidget {
  const StatementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statementControllerProvider);
    final controller = ref.read(statementControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Statement')),
      body: async.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('$e', style: AppText.body)),
        data: (state) {
          if (state.entries.isEmpty && state.error != null) {
            return AppErrorState(
                error: state.error!, onRetry: controller.refresh);
          }
          return CursorList<LedgerEntry>(
            items: state.entries,
            hasMore: state.hasMore,
            isLoadingMore: state.isLoadingMore,
            onLoadMore: controller.loadMore,
            onRefresh: controller.refresh,
            header: _balanceHeader(state),
            emptyState: const AppEmptyState(
              icon: Icons.receipt_long,
              title: 'No entries yet',
              message: 'Earnings and charges will appear here.',
            ),
            itemBuilder: (_, entry) => LedgerRow(
              entry: entry,
              onDispute: (e) => _dispute(context, e),
            ),
          );
        },
      ),
    );
  }

  Widget _balanceHeader(StatementState state) {
    final owes = state.balance.isNegative;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(owes ? 'You owe' : 'Your balance', style: AppText.caption),
          const SizedBox(height: 4),
          Text(
            state.balance.format(),
            style: AppText.money.copyWith(
              color: owes ? AppColors.negative : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _dispute(BuildContext context, LedgerEntry entry) {
    // Files a support ticket citing this ledger entry — wired in Batch 7
    // alongside the rest of the support surface.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Disputing "${entry.displayTitle}"')),
    );
  }
}
