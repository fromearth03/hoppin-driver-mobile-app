import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../core/result.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../statement/data/ledger_repository.dart';
import '../../../statement/data/models/ledger_summary.dart';
import '../../data/models/wallet.dart';

/// The design's dark balance overlays: "What company owes you" when the
/// settled balance is positive, "What you owe the company" when the driver
/// is in debt — a charcoal card floating over the blurred earnings page.
///
/// The line items are `GET /drivers/me/ledger/summary` verbatim: opening,
/// credits in, charges out, closing. The design's itemised rows ("Tip
/// correction", "Ride Bonus - Feb") and its "Estimated payouts: Monday
/// 09:00 via Visa…" footer have no fields behind them — the summary is the
/// only breakdown the service publishes, so it is what is shown.
class OwesDialog extends ConsumerStatefulWidget {
  final Wallet wallet;

  /// Dispute routes to the statement page, where every charge carries its
  /// own dispute affordance — a dispute needs a specific ledger entry.
  final VoidCallback onDispute;

  const OwesDialog({super.key, required this.wallet, required this.onDispute});

  static Future<void> show(
    BuildContext context, {
    required Wallet wallet,
    required VoidCallback onDispute,
  }) =>
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Balance details',
        barrierColor: Colors.black.withValues(alpha: 0.20),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) =>
            OwesDialog(wallet: wallet, onDispute: onDispute),
        transitionBuilder: (_, anim, __, child) => BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: 8 * anim.value, sigmaY: 8 * anim.value),
          child: FadeTransition(opacity: anim, child: child),
        ),
      );

  @override
  ConsumerState<OwesDialog> createState() => _OwesDialogState();
}

class _OwesDialogState extends ConsumerState<OwesDialog> {
  static const _card = Color(0xFF2F2F31);
  static const _rule = Color(0xFF4A4A4E);

  Wallet get wallet => widget.wallet;

  /// Fetched once for the dialog's life — a rebuild (a resize on web, any
  /// inherited change) must not re-hit the API and flash the spinner.
  late final Future<Result<LedgerSummary>> _summary =
      ref.read(ledgerRepositoryProvider).summary('week');

  @override
  Widget build(BuildContext context) {
    final owes = wallet.owes;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: FutureBuilder<Result<LedgerSummary>>(
              future: _summary,
              builder: (context, snapshot) {
                final summary = snapshot.data?.valueOrNull;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              owes
                                  ? 'What you owe the company'
                                  : 'What company owes you',
                              style: AppText.heading
                                  .copyWith(color: Colors.white, fontSize: 18),
                            ),
                          ),
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.of(context).pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close,
                                  size: 20, color: Color(0xFFB9B9C0)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 1, color: _rule),
                      const SizedBox(height: 12),
                      _lead(owes),
                      const SizedBox(height: 12),
                      if (summary == null && !snapshot.hasData)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        )
                      else if (summary != null) ...[
                        _row('Opening balance', summary.opening),
                        _row('Credits in', summary.credits,
                            colour: AppColors.positive),
                        _row('Charges out', summary.debits,
                            colour: AppColors.statRed),
                        const SizedBox(height: 4),
                        const Divider(height: 1, color: _rule),
                        const SizedBox(height: 10),
                        _row(
                          owes ? 'Total Outstanding' : 'Total owed to you',
                          // The same figure the rows sum to — never the
                          // wallet's separately-fetched number, which can
                          // disagree by a race or a rounding. A debt shows
                          // its magnitude: a minus under "you owe" reads as
                          // the company owing the driver.
                          Pence(summary.closing.pence.abs()),
                          bold: true,
                          colour: owes ? AppColors.statRed : Colors.white,
                        ),
                      ] else
                        Text(
                          "The breakdown isn't available right now.",
                          style:
                              AppText.body.copyWith(color: Colors.white70),
                        ),
                      if (owes) ...[
                        const SizedBox(height: 12),
                        Text(
                          'This amount will be auto-deducted from your next '
                          'payout. No action needed unless disputed.',
                          style: AppText.caption
                              .copyWith(color: AppColors.warning),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _chip(
                            label: 'Close',
                            background: const Color(0xFF444448),
                            foreground: Colors.white,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 10),
                          // Both cases can walk into the statement — the
                          // per-charge dispute lives there, and a driver the
                          // company owes still deserves the itemised view.
                          _chip(
                            label:
                                owes ? 'Dispute Charge' : 'View statement',
                            background: Colors.white,
                            foreground: AppColors.textPrimary,
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onDispute();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _lead(bool owes) => Text(
        owes
            ? 'Outstanding Balance — ${Pence(wallet.availableBalance.pence.abs()).format()}'
            : "This week's account movement",
        style: AppText.body.copyWith(color: Colors.white),
      );

  Widget _row(String label, Pence amount, {Color? colour, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppText.body.copyWith(
                  color: Colors.white,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              amount.format(),
              style: AppText.body.copyWith(
                color: colour ?? Colors.white,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );

  Widget _chip({
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) =>
      Material(
        color: background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Text(
              label,
              style: AppText.body.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
}
