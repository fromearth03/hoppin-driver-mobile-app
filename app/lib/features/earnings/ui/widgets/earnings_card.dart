import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

/// The white rounded panel every block on the earnings screen sits in.
///
/// The design uses one shape throughout — 16pt radius, 20pt inset, no
/// shadow — so it lives here rather than being restated per section.
class EarningsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  /// A hairline outline. Drawn on the selected period card, and — in the
  /// card's own accent — on every tinted one, so the four period blocks read
  /// as four distinct things rather than one grey field.
  final bool outlined;

  /// The card's colour. Null keeps the plain white panel used by every
  /// section; a colour tints the ground and the border with it, which is how
  /// the period cards tell today from this week at a glance.
  final Color? accent;

  const EarningsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.fromLTRB(20, 0, 20, 16),
    this.outlined = false,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tint = accent;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        // A wash rather than a fill: the figure on top has to stay the
        // loudest thing in the card.
        color: tint == null
            ? AppColors.surface
            : Color.alphaBlend(tint.withValues(alpha: 0.09), AppColors.surface),
        borderRadius: BorderRadius.circular(16),
        border: switch ((tint, outlined)) {
          // Selected and tinted: the accent at full strength, wide enough to
          // be unmistakable against its three neighbours.
          (final Color c, true) => Border.all(color: c, width: 2),
          (final Color c, false) =>
            Border.all(color: c.withValues(alpha: 0.30)),
          (null, true) => Border.all(color: AppColors.textSecondary),
          (null, false) => Border.all(color: AppColors.border),
        },
      ),
      child: child,
    );
  }
}

/// A section title inside a card — "Payouts", "Earnings Report". The design
/// sets these noticeably larger than a list heading, at the title step.
class EarningsSectionTitle extends StatelessWidget {
  final String text;

  /// The design pairs two section titles with a text action on the right
  /// ("View All Trips"). Null leaves the row title-only.
  final Widget? trailing;

  const EarningsSectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      );
}
