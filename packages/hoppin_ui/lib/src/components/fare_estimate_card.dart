import 'package:flutter/material.dart';

import '../theme/context_extension.dart';
import '../tokens/spacing.dart';

/// One line in a [FareEstimateCard]: a [label] and its [amount]. A surge line
/// additionally carries a [surgeMultiplier] rendered in red.
class FareLine {
  /// Creates a fare line.
  const FareLine({
    required this.label,
    required this.amount,
    this.surgeMultiplier,
  });

  /// Left-hand descriptor — "Base fare", "Distance", "Surge".
  final String label;

  /// Right-hand money value — "£4.20".
  final String amount;

  /// Optional surge multiplier ("1.5x") rendered in the red role after the
  /// label. Null on ordinary lines.
  final String? surgeMultiplier;
}

/// The fare-estimate breakdown card (Figma: Book Ride).
///
/// White card (`radii.card`). Each [FareLine] is a label/amount row at
/// ~68% ink; a surge line adds the red multiplier. A hairline divider
/// separates the lines from the centred total in the `fareTotal`
/// (Poppins SemiBold ~22 navy) style.
class FareEstimateCard extends StatelessWidget {
  /// Creates a fare-estimate card.
  const FareEstimateCard({
    required this.lines,
    required this.totalAmount,
    this.totalLabel = 'Total',
    super.key,
  });

  /// The breakdown rows.
  final List<FareLine> lines;

  /// The centred total money value — "£8.36".
  final String totalAmount;

  /// The label above/around the total; defaults to "Total".
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final radius = BorderRadius.circular(hoppin.radii.card);

    final surface = Material(
      color: colors.card,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(hoppin.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in lines) ...[
              _line(context, line),
              SizedBox(height: hoppin.spacing.sm),
            ],
            Divider(color: colors.hairline, height: hoppin.spacing.md),
            SizedBox(height: hoppin.spacing.sm),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    totalLabel,
                    style:
                        hoppin.type.meta.copyWith(color: colors.textMid),
                  ),
                  SizedBox(height: hoppin.spacing.xs),
                  Text(
                    totalAmount,
                    style:
                        hoppin.type.fareTotal.copyWith(color: colors.textHi),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: HoppinShadows.card,
      ),
      child: surface,
    );
  }

  Widget _line(BuildContext context, FareLine line) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final amountStyle = hoppin.type.body.copyWith(color: colors.textHi);
    return Row(
      children: [
        Text(
          line.label,
          style: hoppin.type.body.copyWith(color: colors.textMid),
        ),
        if (line.surgeMultiplier != null) ...[
          SizedBox(width: hoppin.spacing.sm),
          Text(
            line.surgeMultiplier!,
            style: hoppin.type.bodyMedium.copyWith(color: colors.error),
          ),
        ],
        const Spacer(),
        Text(line.amount, style: amountStyle),
      ],
    );
  }
}
