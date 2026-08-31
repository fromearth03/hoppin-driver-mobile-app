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

  /// A hairline outline. The design draws it only on the selected period
  /// card; everything else is borderless white on the grey ground.
  final bool outlined;

  const EarningsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.fromLTRB(20, 0, 20, 16),
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: outlined
              ? Border.all(color: AppColors.textSecondary, width: 1)
              : null,
        ),
        child: child,
      );
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
          Expanded(child: Text(text, style: AppText.title)),
          if (trailing != null) trailing!,
        ],
      );
}
