import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../data/models/driver_document.dart';

/// One document and what the driver should do about it.
///
/// A rejection shows the admin's reason in full. That single field is the
/// difference between a driver fixing the problem and re-uploading the same
/// file until they call support.
class DocumentCard extends StatelessWidget {
  final DocumentSlot slot;
  final VoidCallback? onUpload;

  const DocumentCard({super.key, required this.slot, this.onUpload});

  (String, Color, IconData) get _statusChip => switch (slot.status) {
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
    final (label, colour, icon) = _statusChip;
    final document = slot.document;

    // Upload is offered only when the driver can actually supply the file
    // and there is something to do — never while a review is in flight.
    final canUpload = slot.type.uploadable &&
        slot.status != DocumentStatus.pending &&
        slot.status != DocumentStatus.approved;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: slot.needsAction ? AppColors.negative : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(slot.type.label, style: AppText.heading)),
              Icon(icon, size: 16, color: colour),
              const SizedBox(width: 4),
              Text(label, style: AppText.caption.copyWith(color: colour)),
            ],
          ),
          if (document?.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.negative.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(document!.rejectionReason!, style: AppText.caption),
            ),
          ],
          if (document?.expiresAt != null &&
              document!.rejectionReason == null) ...[
            const SizedBox(height: 6),
            Text(
              'Expires ${DateFormat('d MMM yyyy').format(document.expiresAt!.toLocal())}',
              style: AppText.caption.copyWith(
                color: document.isExpiringSoon || document.isExpired
                    ? AppColors.negative
                    : AppColors.textSecondary,
              ),
            ),
          ],
          if (canUpload) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onUpload,
                child: const Text('Upload'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
