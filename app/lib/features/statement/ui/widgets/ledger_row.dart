import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/ledger_entry.dart';

/// One movement, in the server's words.
///
/// Nothing here composes copy: `displayTitle` and `displayReason` are printed
/// as received. Dispute is a per-row action so the support ticket cites the
/// exact entry rather than asking the driver to re-identify it.
class LedgerRow extends StatelessWidget {
  final LedgerEntry entry;
  final void Function(LedgerEntry)? onDispute;

  const LedgerRow({super.key, required this.entry, this.onDispute});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(entry.displayTitle, style: AppText.body),
                ),
                Text(
                  entry.amount.formatSigned(),
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        entry.isCredit ? AppColors.positive : AppColors.negative,
                  ),
                ),
              ],
            ),
            if (entry.displayReason != null) ...[
              const SizedBox(height: 4),
              Text(entry.displayReason!, style: AppText.caption),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${DateFormat('d MMM').format(entry.createdAt)} · '
                  'Balance ${entry.runningBalance.format()}',
                  style: AppText.caption,
                ),
                const Spacer(),
                // Only a charge can be disputed — offering it on money the
                // driver was paid would be nonsense.
                if (!entry.isCredit && onDispute != null)
                  TextButton(
                    onPressed: () => onDispute!(entry),
                    child: const Text('Dispute'),
                  ),
              ],
            ),
            const Divider(height: 20, color: AppColors.border),
          ],
        ),
      );
}
