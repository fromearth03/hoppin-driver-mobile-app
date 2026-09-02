import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/wallet.dart';

/// One payout, read-only.
///
/// Payouts are run by the operator on a weekly or monthly cycle. A failed
/// one shows the reason, but there is deliberately no Retry — the design
/// puts one beside the failure reason, and there is no endpoint behind it:
/// the driver cannot re-run an operator's transfer, and a button that
/// cannot work is worse than none.
class PayoutRow extends StatelessWidget {
  final Payout payout;

  const PayoutRow({super.key, required this.payout});

  bool get _failed => payout.status == 'failed';

  /// The design prints "Payout ID: Pay 48270". The service sends a UUID, so
  /// the short head of it stands in — enough for a driver to quote to
  /// support, and it is the real identifier rather than an invented number.
  String get _reference =>
      payout.id.isEmpty ? 'Payout' : 'Payout ${payout.id.split('-').first}';

  @override
  Widget build(BuildContext context) {
    final colour = _failed ? AppColors.negative : AppColors.positive;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                _failed ? Icons.cancel : Icons.check_circle,
                size: 24,
                color: colour,
              ),
              const SizedBox(width: 12),
              // Two columns, not four. Three flex boxes competing for one
              // row is what clipped a payout reference to "someth…" — the
              // string a driver reads out to support when a transfer goes
              // missing, and the one thing on the row that must survive
              // whole.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_reference,
                        maxLines: 2,
                        style: AppText.heading.copyWith(fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(
                      payout.transferredAt == null
                          ? _statusLabel
                          : DateFormat('EEEE, d MMM yyyy')
                              .format(payout.transferredAt!.toLocal()),
                      maxLines: 2,
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // The money and its status stack on the right, each sized to
              // itself rather than to a share of the row.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    payout.amount.format(),
                    maxLines: 1,
                    style: AppText.heading.copyWith(
                      fontSize: 16,
                      color:
                          _failed ? AppColors.negative : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _statusLabel,
                    maxLines: 1,
                    style: AppText.body.copyWith(fontSize: 14, color: colour),
                  ),
                ],
              ),
            ],
          ),
          if (payout.failureReason != null) ...[
            const SizedBox(height: 12),
            // The design's pale red pill under a failed payout. Its Retry
            // chip is still not drawn — there is no endpoint behind it.
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.tintRed,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text('Reason: ${payout.failureReason}',
                  style: AppText.body
                      .copyWith(fontSize: 14, color: AppColors.textPrimary)),
            ),
          ],
        ],
      ),
    );
  }

  /// The service's own status word, capitalised. Not remapped: "paid",
  /// "failed" and "pending" are what the payout batch actually says.
  String get _statusLabel {
    if (payout.status.isEmpty) return '';
    return payout.status[0].toUpperCase() + payout.status.substring(1);
  }
}
