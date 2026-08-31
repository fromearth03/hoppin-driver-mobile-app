import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/ledger_entry.dart';

/// One movement, in the server's words, drawn as the design draws a money
/// line: the title and the signed amount on one line, the server's reason
/// under it, and the date and running balance in caption grey.
///
/// Nothing here composes copy: `displayTitle` and `displayReason` are printed
/// as received. Dispute is a per-row action so the support ticket cites the
/// exact entry rather than asking the driver to re-identify it.
class LedgerRow extends StatelessWidget {
  final LedgerEntry entry;
  final void Function(LedgerEntry)? onDispute;

  const LedgerRow({super.key, required this.entry, this.onDispute});

  @override
  Widget build(BuildContext context) {
    // Only a charge can be disputed — offering it on money the driver was
    // paid would be nonsense.
    final disputable = !entry.isCredit && onDispute != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(entry.displayTitle,
                    style: AppText.body.copyWith(fontSize: 17)),
              ),
              const SizedBox(width: 12),
              Text(
                entry.amount.formatSigned(),
                style: AppText.body.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color:
                      entry.isCredit ? AppColors.positive : AppColors.negative,
                ),
              ),
            ],
          ),
          if (entry.displayReason != null) ...[
            const SizedBox(height: 6),
            Text(entry.displayReason!, style: AppText.caption),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DateFormat('d MMM').format(entry.createdAt)} · '
                  'Balance ${entry.runningBalance.format()}',
                  style: AppText.caption,
                ),
              ),
              if (disputable)
                TextButton(
                  onPressed: () => onDispute!(entry),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Dispute',
                      style: AppText.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
