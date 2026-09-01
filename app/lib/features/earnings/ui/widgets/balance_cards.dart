import 'package:flutter/material.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/wallet.dart';
import 'earnings_card.dart';

/// The pair of balance tiles under the breakdown.
///
/// The design shows two cards both captioned "Company Owes You", one green
/// and one red, with different amounts — which cannot both be true, and a
/// red "owes you" is a contradiction. The wallet endpoint returns two real
/// and distinct figures, so the layout is kept and each tile is captioned
/// for the figure it actually holds: the settled balance (which goes red
/// and flips to "You Owe" when a driver is in debt — that happens, and the
/// ledger is the source of truth for it) and the balance still pending.
class BalanceCards extends StatelessWidget {
  final Wallet wallet;
  final VoidCallback onViewStatement;

  const BalanceCards({
    super.key,
    required this.wallet,
    required this.onViewStatement,
  });

  @override
  Widget build(BuildContext context) {
    final owes = wallet.owes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      // The two tiles hold different amounts of content — only the settled
      // one carries a button — and the design draws them the same height.
      // Inside a vertically unbounded scroll view a stretched Row cannot
      // measure itself, so the height is taken from the taller child.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _tile(
                // Magnitude under a "You Owe" caption — the caption already
                // states the direction; a minus on top of it reads as the
                // company owing the driver. Same rule as the statement panel.
                amount: Pence(wallet.availableBalance.pence.abs()).format(),
                caption: owes ? 'You Owe' : 'Company Owes You',
                // The design's coral, not the deeper crimson — this card is
                // a statement of balance, not an error state.
                colour: owes ? AppColors.statRed : AppColors.positive,
                action: 'View Details',
                onTap: onViewStatement,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _tile(
                amount: wallet.pendingBalance.format(),
                caption: 'Pending',
                colour: AppColors.textPrimary,
                // Pending money has nothing to open: it is the same ledger,
                // not yet settled. A second button to the same page would be
                // a duplicate, so the tile is a figure and a caption.
                action: null,
                onTap: null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required String amount,
    required String caption,
    required Color colour,
    String? action,
    VoidCallback? onTap,
  }) =>
      EarningsCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(amount,
                  style: AppText.title.copyWith(fontSize: 26, color: colour)),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(caption,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(fontSize: 14, color: colour)),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: colour,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // The tile is half the screen wide; the label and its
                  // arrow scale down together rather than clipping.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(action,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward,
                            size: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}
