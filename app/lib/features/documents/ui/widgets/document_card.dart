import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/driver_document.dart';

/// One document tile in the grid.
///
/// The design draws a bespoke line illustration per document type, the type
/// name, and an "Expire: <date>" line. We keep that shape, substituting an
/// outlined Material glyph per type.
///
/// The design's corner glyph is the same crossed-out eye on every tile —
/// decorative, and it would leave a driver unable to tell an approved
/// licence from a rejected one. It is replaced with the document's real
/// verification status, which is the one thing this screen exists to show.
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

  /// The eight codes the service's catalogue serves, plus the aliases older
  /// payloads used. An unknown code falls back to a generic page.
  static const _glyphs = {
    'dvla_license': Icons.badge_outlined,
    'wolverhampton_taxi_badge': Icons.local_taxi_outlined,
    'right_to_work': Icons.fact_check_outlined,
    'mot_certificate': Icons.build_outlined,
    'insurance_policy': Icons.shield_outlined,
    'v5c_logbook': Icons.article_outlined,
    'caz_compliance_proof': Icons.eco_outlined,
    'nr3s_background_check': Icons.verified_user_outlined,
    'private_hire_license': Icons.badge_outlined,
    'driving_license': Icons.badge_outlined,
    'vehicle_insurance': Icons.shield_outlined,
    'dbs_check': Icons.verified_outlined,
    'medical_certificate': Icons.medical_information_outlined,
  };

  IconData get _glyph => _glyphs[slot.type.code] ?? Icons.description_outlined;

  (String, Color, IconData) get statusChip => switch (slot.status) {
        DocumentStatus.approved => (
            'Approved',
            AppColors.positive,
            Icons.check_circle
          ),
        DocumentStatus.pending => (
            'Under review',
            AppColors.warning,
            Icons.schedule
          ),
        DocumentStatus.rejected => (
            'Not accepted',
            AppColors.negative,
            Icons.error
          ),
        DocumentStatus.expired => (
            'Expired',
            AppColors.negative,
            Icons.event_busy
          ),
        DocumentStatus.missing => (
            'Not uploaded',
            AppColors.textSecondary,
            Icons.upload_file
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
                    ? AppColors.negative.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_glyph, size: 36, color: AppColors.textPrimary),
                    const Spacer(),
                    Tooltip(
                      message: label,
                      child: Icon(statusIcon, size: 18, color: colour),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  slot.type.label,
                  style: AppText.heading.copyWith(fontSize: 15.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  // The design prints "Expire: January 15, 2026" on every
                  // tile. Only a type the service marks as expiring carries
                  // a date; the rest state their status rather than a date
                  // we would have to invent.
                  expiry == null
                      ? label
                      : 'Expire: ${DateFormat('MMMM d, y').format(expiry.toLocal())}',
                  style: AppText.caption.copyWith(
                    color: slot.needsAction ||
                            (document?.isExpiringSoon ?? false)
                        ? AppColors.negative
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The design's dark "Document Appeal" tile, in the last grid cell.
///
/// There is no document-appeal endpoint. `POST /drivers/me/compliance-appeals`
/// is the only path, and it takes a `document_type` and a free-text reason —
/// which is exactly a document appeal, so the tile is real and wired to it.
class DocumentAppealCard extends StatelessWidget {
  final VoidCallback onTap;

  const DocumentAppealCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Appeal a document decision',
        child: Material(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.gavel_outlined,
                          size: 36, color: AppColors.surface),
                      const Spacer(),
                      Icon(Icons.add,
                          size: 24,
                          color: AppColors.surface.withValues(alpha: 0.9)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Document\nAppeal',
                    style: AppText.heading.copyWith(
                      fontSize: 15.5,
                      color: AppColors.surface,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
