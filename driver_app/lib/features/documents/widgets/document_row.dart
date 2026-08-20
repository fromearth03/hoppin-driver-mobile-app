import 'package:flutter/material.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../document_type_labels.dart';
import 'document_status_chip.dart';

/// The upload entry point.
///
/// LANE B (13-02) supplies the real implementation — the presigned
/// `POST /drivers/me/documents/upload-url` → `PUT` → `POST /drivers/me/documents`
/// confirm chain. This plan defines the CONTRACT so the two lanes never touch
/// the same file.
typedef DocumentUploadRequest = Future<void> Function(String documentType);

/// One row of the compliance wallet: one of the backend's eight
/// `document_type`s, and whatever the server has (or has not) said about it.
///
/// 🔴 THE TWO BRANCHES ARE NOT SYMMETRICAL AND MUST NOT BE MADE SO.
///
/// `document != null` → the server has a row for this type, so we render the
/// server's OWN `verification_status` token through [DocumentStatusChip].
///
/// `document == null` → the driver has uploaded NOTHING. That is **NOT
/// UPLOADED**. It is not "pending", it is not "awaiting review", it is not
/// "submitted", and it is emphatically not valid. Inventing a submission that
/// never happened is how a driver ends up believing they are compliant while
/// their licence sits on their kitchen table.
class DocumentRow extends StatelessWidget {
  /// Creates the row for [documentType].
  const DocumentRow({
    required this.documentType,
    required this.document,
    required this.onUpload,
    this.onAppeal,
    super.key,
  });

  /// One of `DriverRepository.documentTypes`. The row NEVER invents a type.
  final String documentType;

  /// The newest server row of this type, or null when the driver has uploaded
  /// none. 🔴 Null means NOT UPLOADED.
  final DriverDocument? document;

  /// Fires the upload chain for [documentType] (LANE B owns the chain).
  final DocumentUploadRequest onUpload;

  /// Opens a compliance appeal ticket for the current document, when supplied.
  final VoidCallback? onAppeal;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final doc = document;

    return HopCard(
      onTap: () => onUpload(documentType),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  documentTypeLabel(documentType),
                  style: hoppin.type.bodyMedium.copyWith(color: colors.textHi),
                ),
                SizedBox(height: hoppin.spacing.xs),
                if (doc == null)
                  // The honest empty branch. The words a driver reads here are
                  // load-bearing: they must carry NO implication that anything
                  // has been submitted or is being looked at.
                  Text(
                    'Not uploaded',
                    style:
                        hoppin.type.metaSmall.copyWith(color: colors.textMid),
                  )
                else
                  DocumentStatusChip(status: doc.verificationStatus),
                if (doc != null && onAppeal != null) ...[
                  SizedBox(height: hoppin.spacing.xs),
                  TextButton.icon(
                    onPressed: onAppeal,
                    icon: const Icon(Icons.gavel_outlined, size: 16),
                    label: const Text('Appeal this document'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: hoppin.spacing.sm),
          Icon(
            doc == null ? Icons.upload_file_outlined : Icons.autorenew,
            color: colors.textMid,
            semanticLabel: doc == null
                ? 'Upload ${documentTypeLabel(documentType)}'
                : 'Replace ${documentTypeLabel(documentType)}',
          ),
        ],
      ),
    );
  }
}
