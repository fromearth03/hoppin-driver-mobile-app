import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/appeal.dart';
import '../../data/models/penalty.dart';

/// Penalties and the appeals against them, in one place — they are one
/// story, and splitting them would leave a driver checking two screens to
/// learn what happened to a challenge they filed.
///
/// The design groups them into three expandable rows: Active, Under review
/// and Resolved. Only one is open at a time, matching the Figma states.
class PenaltiesSection extends StatefulWidget {
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
  State<PenaltiesSection> createState() => _PenaltiesSectionState();
}

enum _Group { active, underReview, resolved }

class _PenaltiesSectionState extends State<PenaltiesSection> {
  _Group? _open;

  @override
  Widget build(BuildContext context) {
    final active = widget.penalties?.penalties ?? const <Penalty>[];
    final underReview = widget.appeals.where((a) => !a.isResolved).toList();
    final resolved = widget.appeals.where((a) => a.isResolved).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Penalties and Appeals', style: AppText.title),
          const SizedBox(height: 2),
          const Text('Track your account status and any penalties',
              style: AppText.bodySecondary),
          const SizedBox(height: 12),
          if (active.isEmpty && widget.appeals.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('No penalties on your account.',
                  style: AppText.bodySecondary),
            )
          else ...[
            if (active.isNotEmpty)
              _group(
                group: _Group.active,
                icon: Icons.error_outline,
                tint: AppColors.statRed,
                circle: AppColors.tintRed,
                title: 'Active (${active.length})',
                subtitle: active.length == 1
                    ? '1 penalty currently affecting your account'
                    : '${active.length} penalties currently affecting your account',
                children: active.map(_penaltyRow).toList(),
              ),
            if (underReview.isNotEmpty)
              _group(
                group: _Group.underReview,
                icon: Icons.restore,
                tint: AppColors.warning,
                circle: AppColors.tintAmber,
                title: 'Under review (${underReview.length})',
                subtitle: underReview.length == 1
                    ? '1 appeal is being reviewed'
                    : '${underReview.length} appeals are being reviewed',
                children: underReview.map(_appealRow).toList(),
              ),
            if (resolved.isNotEmpty)
              _group(
                group: _Group.resolved,
                icon: Icons.check_rounded,
                tint: AppColors.positive,
                circle: AppColors.tintMint,
                solid: true,
                title: 'Resolved (${resolved.length})',
                subtitle: resolved.length == 1
                    ? '1 appeal has been resolved'
                    : '${resolved.length} appeals have been resolved',
                children: resolved.map(_appealRow).toList(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _group({
    required _Group group,
    required IconData icon,
    required Color tint,
    required Color circle,
    required String title,
    required String subtitle,
    required List<Widget> children,
    bool solid = false,
  }) {
    final open = _open == group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: AppColors.border),
        InkWell(
          onTap: () => setState(() => _open = open ? null : group),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // Resolved is the one solid disc in the design — a green
                // circle with a white check; the open states sit as tinted
                // outlines on their pale grounds.
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: solid ? tint : circle,
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(icon, size: 19, color: solid ? Colors.white : tint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.heading.copyWith(fontSize: 16)),
                      const SizedBox(height: 1),
                      Text(subtitle,
                          style: AppText.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(
                  open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.textDisabled,
                ),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(children: children),
          ),
      ],
    );
  }

  /// The design's tinted detail card: title, date and amount, then the
  /// appeal affordance.
  Widget _detailCard({
    required Color tint,
    required String title,
    required String meta,
    String? footer,
    Widget? action,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // The design's pale panel colours, laid flat — not an alpha mix
          // that would shift on any other ground.
          color: tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.heading.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(meta, style: AppText.caption),
                    ],
                  ),
                ),
                if (action != null) ...[const SizedBox(width: 8), action],
              ],
            ),
            if (footer != null) ...[
              const SizedBox(height: 10),
              Text(footer, style: AppText.body),
            ],
          ],
        ),
      );

  Widget _penaltyRow(Penalty p) {
    final date = DateFormat('d MMM yyyy').format(p.createdAt.toLocal());
    return _detailCard(
      tint: AppColors.tintRed,
      title: p.displayTitle,
      meta: '$date · Penalty: ${p.amount.format()}',
      // The design's third line is "Appeal window: 48h left". No penalty
      // field carries a deadline, so the reason for the penalty goes here
      // instead — the thing the driver actually needs in order to appeal.
      footer: p.displayReason,
      // Appeal appears only where the server says the penalty can be
      // appealed at all.
      action: p.appealable && widget.onAppeal != null
          ? _AppealButton(onPressed: () => widget.onAppeal!(p))
          : null,
    );
  }

  Widget _appealRow(Appeal a) {
    final (label, tint) = switch (a.status) {
      AppealStatus.approved => ('Approved', AppColors.tintMint),
      AppealStatus.rejected => ('Rejected', AppColors.tintRed),
      AppealStatus.underReview => ('Under review', AppColors.tintAmber),
    };
    final decided = a.reviewedAt ?? a.createdAt;
    final date = DateFormat('d MMM yyyy').format(decided.toLocal());

    return _detailCard(
      tint: tint,
      title: a.reason.isEmpty ? 'Appeal' : a.reason,
      meta: a.documentType == null
          ? '$date · $label'
          : '$date · ${a.documentType} · $label',
      // The reviewer's own words. An appeal answered with a bare status is
      // what this field exists to prevent. The design's "Decision within
      // 24h" line promises a turnaround nothing in the contract states, so
      // it is not reproduced.
      footer: a.reviewNote,
    );
  }
}

/// The design's red pill. Small and inline, not a full-width button.
class _AppealButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AppealButton({required this.onPressed});

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.statRed,
          foregroundColor: AppColors.surface,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text('Appeal'),
      );
}
