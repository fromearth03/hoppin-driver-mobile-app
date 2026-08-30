import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/appeal.dart';
import '../../data/models/penalty.dart';

/// Penalties and the appeals against them, in one place — they are one
/// story, and splitting them would leave a driver checking two screens to
/// learn what happened to a challenge they filed.
class PenaltiesSection extends StatelessWidget {
  final PenaltyList? penalties;
  final List<Appeal> appeals;
  final void Function(Penalty)? onAppeal;

  const PenaltiesSection({
    super.key,
    required this.penalties,
    this.appeals = const [],
    this.onAppeal,
  });

  @override
  Widget build(BuildContext context) {
    final items = penalties?.penalties ?? const <Penalty>[];
    final underReview = appeals.where((a) => !a.isResolved).toList();
    final resolved = appeals.where((a) => a.isResolved).toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Penalties and appeals', style: AppText.heading),
          const SizedBox(height: 4),
          const Text('Track your account status and any penalties',
              style: AppText.caption),
          const SizedBox(height: 12),
          if (items.isEmpty && appeals.isEmpty)
            const Text('No penalties on your account.',
                style: AppText.bodySecondary)
          else ...[
            ...items.map(_penaltyRow),
            // The headers count appeals; each row carries its own status
            // chip. They say different things so the same words do not
            // appear twice for a driver with a single open appeal.
            if (underReview.isNotEmpty) ...[
              const Divider(height: 24, color: AppColors.border),
              Text('Appeals awaiting a decision (${underReview.length})',
                  style: AppText.body),
              ...underReview.map(_appealRow),
            ],
            if (resolved.isNotEmpty) ...[
              const Divider(height: 24, color: AppColors.border),
              Text('Appeals decided (${resolved.length})', style: AppText.body),
              ...resolved.map(_appealRow),
            ],
          ],
        ],
      ),
    );
  }

  Widget _penaltyRow(Penalty p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(p.displayTitle, style: AppText.body)),
                Text(p.amount.format(),
                    style: AppText.body.copyWith(color: AppColors.negative)),
              ],
            ),
            if (p.displayReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(p.displayReason!, style: AppText.caption),
              ),
            Row(
              children: [
                Text(DateFormat('d MMM yyyy').format(p.createdAt),
                    style: AppText.caption),
                const Spacer(),
                // Appeal appears only where the server says the penalty can
                // be appealed at all.
                if (p.appealable && onAppeal != null)
                  TextButton(
                    onPressed: () => onAppeal!(p),
                    child: const Text('Appeal'),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _appealRow(Appeal a) {
    final (label, colour) = switch (a.status) {
      AppealStatus.approved => ('Approved', AppColors.positive),
      AppealStatus.rejected => ('Rejected', AppColors.negative),
      AppealStatus.underReview => ('Under review', AppColors.warning),
    };

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(a.reason, style: AppText.body)),
              Text(label, style: AppText.caption.copyWith(color: colour)),
            ],
          ),
          // The reviewer's own words. An appeal answered with a bare status
          // is what this field exists to prevent.
          if (a.reviewNote != null) ...[
            const SizedBox(height: 6),
            Text(a.reviewNote!, style: AppText.caption),
          ],
        ],
      ),
    );
  }
}
