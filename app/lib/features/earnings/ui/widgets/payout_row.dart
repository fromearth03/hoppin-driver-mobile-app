import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/wallet.dart';

/// One payout, read-only.
///
/// Payouts are run by the operator on a weekly or monthly cycle. A failed
/// one shows the reason, but there is deliberately no Retry: the driver
/// cannot re-run an operator's transfer, and a button that cannot work is
/// worse than none.
class PayoutRow extends StatelessWidget {
  final Payout payout;

  const PayoutRow({super.key, required this.payout});

  bool get _failed => payout.status == 'failed';

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _failed ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: _failed ? AppColors.negative : AppColors.positive,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payout.transferredAt == null
                        ? payout.status
                        : DateFormat('d MMM yyyy')
                            .format(payout.transferredAt!.toLocal()),
                    style: AppText.body,
                  ),
                  if (payout.failureReason != null)
                    Text(payout.failureReason!,
                        style:
                            AppText.caption.copyWith(color: AppColors.negative)),
                ],
              ),
            ),
            Text(payout.amount.format(), style: AppText.body),
          ],
        ),
      );
}
