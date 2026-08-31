import 'package:flutter/material.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/ride_earnings.dart';
import 'earnings_card.dart';
import 'period_grid.dart';

/// How the selected period's total was arrived at: what came in, what came
/// off, and what is left.
///
/// The design lists Base Fare, Distance / Time and Surge as separate income
/// rows. The summary endpoint does not split gross that way — it sends
/// gross_pence, commission_pence, tax_pence, penalties_pence and net_pence
/// and nothing else, and the per-component figures exist only per ride. So
/// the layout is the design's, with the one income row the service can
/// actually stand behind. The design also labels its deductions with rates
/// ("Commission (15%)", "Tax (Vat 20%)"); no rate is returned with the
/// figures, and the commission rate varies by operator, so the rows are
/// unlabelled rather than asserting a percentage that may be wrong.
class BreakdownCard extends StatelessWidget {
  final String period;
  final EarningsSummary? summary;

  const BreakdownCard({super.key, required this.period, required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return EarningsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EarningsSectionTitle('${PeriodGrid.labels[period]} Breakdown'),
          const SizedBox(height: 20),
          if (s == null)
            const Text('No breakdown for this period yet.',
                style: AppText.bodySecondary)
          else ...[
            _row('Gross Earnings', s.gross),
            for (final line in s.deductions)
              _row(line.label, line.amount, deduction: true),
            const _DashedDivider(),
            _row('Net Total', s.net, emphasised: true),
            if (s.tripCount > 0) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${s.tripCount} trips', style: AppText.caption),
                  Text('${s.avgNetPerTrip.format()} average',
                      style: AppText.caption),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _row(String label, Pence amount,
          {bool deduction = false, bool emphasised = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: emphasised ? 0 : 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: emphasised
                  ? AppText.heading.copyWith(fontSize: 17)
                  : AppText.body.copyWith(fontSize: 16),
            ),
            Text(
              deduction ? '- ${amount.format()}' : amount.format(),
              style: (emphasised
                      ? AppText.heading.copyWith(fontSize: 17)
                      : AppText.body.copyWith(fontSize: 16))
                  .copyWith(
                color: deduction ? AppColors.negative : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
}

/// The dashed rule the design puts above the net total. Material has no
/// dashed divider, so it is drawn.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 18),
        child: SizedBox(
          height: 1,
          width: double.infinity,
          child: CustomPaint(painter: _DashPainter()),
        ),
      );
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    const dash = 6.0;
    const gap = 5.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
          Offset(x, 0), Offset((x + dash).clamp(0, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
