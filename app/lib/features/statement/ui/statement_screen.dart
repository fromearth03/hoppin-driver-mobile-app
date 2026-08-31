import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../features/profile/ui/widgets/settings_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/cursor_list.dart';
import '../data/models/ledger_entry.dart';
import '../logic/statement_controller.dart';
import 'dispute_sheet.dart';
import 'widgets/balance_panel.dart';
import 'widgets/ledger_row.dart';

/// Both money directions in one place. A negative balance is what the driver
/// owes; a positive one is what the company owes them. The figure is stated
/// plainly — never softened, and never accompanied by a claim about how it
/// will be collected.
///
/// The design puts the money panel in a modal over the statement. It is drawn
/// here as the head of the list instead: it is the number the driver opened
/// the screen for, and hiding it behind a tap would be the wrong trade.
class StatementScreen extends ConsumerWidget {
  const StatementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statementControllerProvider);
    final controller = ref.read(statementControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: settingsAppBar(context, 'Statement'),
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
            header: BalancePanel(
              balance: state.balance,
              summary: state.summary,
            ),
            emptyState: const AppEmptyState(
              icon: Icons.receipt_long,
              title: 'No entries yet',
              message: 'Earnings and charges will appear here.',
            ),
            itemBuilder: (_, entry) => LedgerRow(
              entry: entry,
              onDispute: (e) => _dispute(context, ref, e),
            ),
          );
        },
      ),
    );
  }

  /// Files a support ticket citing this exact ledger entry. There is no
  /// dispute endpoint — a dispute IS a support ticket — so this goes through
  /// the support surface rather than a second path of its own.
  Future<void> _dispute(
    BuildContext context,
    WidgetRef ref,
    LedgerEntry entry,
  ) async {
    final filed = await DisputeSheet.show(context, entry);
    if (!filed || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your dispute has been sent to support.')),
    );
  }
}
