import 'package:flutter/material.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/ledger_summary.dart';

/// The design's money panel — "What you owe the company" when the balance is
/// negative, "What company owes you" when it is not — as a card at the head of
/// the statement rather than as a modal over it. It is the first thing the
/// screen is for; putting it behind a tap would hide the number the driver
/// opened the screen to read.
///
/// The itemised rows are the period figures from
/// `GET /drivers/me/ledger/summary`: opening, credits in, charges out, closing.
/// Those four are the only breakdown the backend publishes.
///
/// Deliberately NOT rendered, each because it has no source:
///
///  * The "Tip correction (3 trips) £30.00" row in the Figma. Tips do not
///    exist anywhere in the backend — there is no tips field on any endpoint,
///    so the row would be a number we invented.
///  * The "Ride Bonus - Feb" row. Bonuses exist (`recent_bonuses` on
///    `/drivers/me/wallet`) but they are not part of the ledger summary and
///    belong to the Earnings surface that reads that endpoint; pulling them in
///    here would double-count them against the closing balance.
///  * "This amount will be auto-deducted from your next payout. No action
///    needed unless disputed." The backend team explicitly refused to state
///    that deduction policy, and the app must not assert a collection method
///    on the business's behalf.
///  * "Estimated payouts: Monday 09:00 AM via Visa Classic 12** …". No
///    endpoint publishes a payout schedule or a card, and drivers are paid by
///    bank transfer through Stripe Connect, not to a card.
class BalancePanel extends StatelessWidget {
  /// The live signed balance from the ledger — negative means the driver owes.
  final Pence balance;

  /// The period breakdown, when it loaded. Null hides the itemised rows and
  /// leaves the headline figure, which is the part that must never be missing.
  final LedgerSummary? summary;

  const BalancePanel({super.key, required this.balance, this.summary});

  @override
  Widget build(BuildContext context) {
    final owes = balance.isNegative;
    final s = summary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              owes ? 'What you owe the company' : 'What the company owes you',
              style: AppText.title.copyWith(fontSize: 20),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  owes ? 'Outstanding balance' : 'Current balance',
                  style: AppText.caption,
                ),
                const SizedBox(height: 6),
                Text(
                  // The magnitude reads as the headline; the sign is carried
                  // by the label and the colour, so a debt is never printed
                  // as a bare minus a driver could misread.
                  Pence(balance.pence.abs()).format(),
                  style: AppText.money.copyWith(
                    color: owes ? AppColors.negative : AppColors.textPrimary,
                  ),
                ),
                if (s != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    s.period == 'month' ? 'Last 30 days' : 'Last 7 days',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 8),
                  // A rule under every entry, not just before the total: four
                  // money rows floating in one field made the driver count
                  // baselines to see which figure belonged to which label.
                  _Line(label: 'Opening balance', amount: s.opening),
                  const _RowRule(),
                  _Line(
                    label: 'Credits in',
                    amount: s.credits,
                    tint: AppColors.positive,
                  ),
                  const _RowRule(),
                  // `debits_pence` arrives negative from the handler; it is
                  // printed as received rather than re-signed here.
                  _Line(
                    label: 'Charges out',
                    amount: s.debits,
                    tint: AppColors.negative,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Divider(
                        height: 1, thickness: 1, color: AppColors.border),
                  ),
                  _Line(
                    label: owes ? 'Total outstanding' : 'Total owed to you',
                    amount: s.closing,
                    strong: true,
                    tint: s.owes ? AppColors.negative : AppColors.textPrimary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The hairline between two money rows. Lighter than the panel's own
/// dividers, so it separates entries without competing with the rule above
/// the total.
class _RowRule extends StatelessWidget {
  const _RowRule();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        color: AppColors.border.withValues(alpha: 0.55),
      );
}

/// One label/amount row in the panel.
class _Line extends StatelessWidget {
  final String label;
  final Pence amount;
  final Color? tint;
  final bool strong;

  const _Line({
    required this.label,
    required this.amount,
    this.tint,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: strong
                    ? AppText.body.copyWith(fontWeight: FontWeight.w600)
                    : AppText.body,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amount.format(),
              style: AppText.body.copyWith(
                fontSize: strong ? 17 : 15,
                fontWeight: FontWeight.w600,
                color: tint ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
}
