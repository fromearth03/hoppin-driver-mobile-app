import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/driver_document.dart';

/// One document tile in the grid.
///
/// The design draws a bespoke line illustration per document type, the type
/// name, and an "Expire: <date>" line. We keep that shape, substituting an
/// outlined Material glyph per type, and add a status marker in the corner —
/// the design's corner glyph is decorative and identical on every tile,
/// which would leave a driver unable to tell an approved licence from a
/// rejected one.
class DocumentCard extends StatelessWidget {
  final DocumentSlot slot;
  final VoidCallback? onTap;

  const DocumentCard({super.key, required this.slot, this.onTap});

  /// Upload is offered only when the driver can actually supply the file and
  /// there is something to do — never while a review is in flight.
  bool get canUpload =>
      slot.type.uploadable &&
      slot.status != DocumentStatus.pending &&
      slot.status != DocumentStatus.approved;

  static const _glyphs = {
    'private_hire_license': Icons.badge_outlined,
    'phv_license': Icons.badge_outlined,
    'driving_license': Icons.badge_outlined,
    'vehicle_insurance': Icons.directions_car_outlined,
    'insurance': Icons.directions_car_outlined,
    'mot': Icons.build_outlined,
    'vehicle_registration': Icons.article_outlined,
    'dbs_check': Icons.verified_outlined,
    'nr3s_background_check': Icons.verified_user_outlined,
    'medical_certificate': Icons.medical_information_outlined,
    'right_to_work': Icons.fact_check_outlined,
  };

  IconData get _glyph =>
      _glyphs[slot.type.code] ?? Icons.description_outlined;

  (String, Color, IconData) get statusChip => switch (slot.status) {
        DocumentStatus.approved => (
            'Approved',
            AppColors.positive,
            Icons.check_circle_outline
          ),
        DocumentStatus.pending => (
            'Under review',
            AppColors.warning,
            Icons.schedule
          ),
        DocumentStatus.rejected => (
            'Not accepted',
            AppColors.negative,
            Icons.error_outline
          ),
        DocumentStatus.expired => (
            'Expired',
            AppColors.negative,
            Icons.event_busy_outlined
          ),
        DocumentStatus.missing => (
            'Not uploaded',
            AppColors.textSecondary,
            Icons.upload_file_outlined
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (label, colour, statusIcon) = statusChip;
    final document = slot.document;
    final expiry = document?.expiresAt;

    return Semantics(
      button: canUpload,
      label: '${slot.type.label}, $label',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: canUpload ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: slot.needsAction
                    ? AppColors.negative.withValues(alpha: 0.45)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_glyph, size: 38, color: AppColors.textPrimary),
                    const Spacer(),
                    Icon(statusIcon, size: 18, color: colour),
                  ],
                ),
                const Spacer(),
                Text(
                  slot.type.label,
                  style: AppText.heading.copyWith(fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  // The design prints "Expire: January 15, 2026" on every
                  // tile. Only a document that actually carries an expiry
                  // gets a date; the rest state their status instead of a
                  // date we do not have.
                  expiry == null
                      ? label
                      : 'Expire: ${DateFormat('MMMM d, y').format(expiry.toLocal())}',
                  style: AppText.caption.copyWith(
                    color: (document?.isExpired ?? false) ||
                            (document?.isExpiringSoon ?? false) ||
                            slot.needsAction
                        ? AppColors.negative
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (document?.rejectionReason != null) ...[
                  const SizedBox(height: 8),
                  // Rendered in full. That single field is the difference
                  // between a driver fixing the problem and re-uploading the
                  // same file until they call support.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.negative.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      document!.rejectionReason!,
                      style: AppText.caption.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
