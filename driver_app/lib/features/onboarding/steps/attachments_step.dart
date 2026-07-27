import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// Registration4, re-purposed — **Attachments**.
///
/// This is the one step of the four whose Figma frame describes something the
/// backend genuinely does. `POST /drivers/me/documents/upload-url` issues a
/// presigned slot, `POST /drivers/me/documents` confirms it, and
/// `GET /drivers/me/documents` reads them back. Eight document types, fully
/// bound.
///
/// **So this step does not re-implement it.** The documents surface is LANE A's
/// (`features/documents/`, at `/documents`) — one list, one uploader, one
/// vocabulary, one place where the truth about a document's status lives. A
/// second copy of it inside the wizard would be a second place for that truth to
/// drift, and the first thing to drift would be the status words: the Figma
/// invented a "Valid" state the backend has never published (#83).
///
/// The wizard's job here is to hand the driver over and get out of the way.
class AttachmentsStep extends StatelessWidget {
  /// Creates the attachments step.
  const AttachmentsStep({
    required this.onBack,
    required this.onContinue,
    required this.onOpenDocuments,
    super.key,
  });

  /// Back to the vehicle step.
  final VoidCallback onBack;

  /// Forward to the completion frame.
  final VoidCallback onContinue;

  /// Out to `/documents` — the real surface (LANE A).
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Upload your compliance documents. Our team reviews each one before '
          'you can start taking rides.',
          style: hoppin.type.meta.copyWith(color: colors.textMid),
        ),
        SizedBox(height: hoppin.spacing.gutter),
        HopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your documents',
                style: hoppin.type.bodyMedium.copyWith(color: colors.textHi),
              ),
              SizedBox(height: hoppin.spacing.sm),
              Text(
                'PDF, JPG or PNG. You can upload them now or come back to them '
                "later — they're always here under Documents.",
                style: hoppin.type.meta.copyWith(color: colors.textMid),
              ),
              SizedBox(height: hoppin.spacing.lg),
              HopButton.primary(
                label: 'Go to documents',
                onPressed: onOpenDocuments,
              ),
            ],
          ),
        ),
        SizedBox(height: hoppin.spacing.xl),
        Row(
          children: [
            Expanded(
              child: HopButton.secondary(label: 'Back', onPressed: onBack),
            ),
            SizedBox(width: hoppin.spacing.lg),
            Expanded(
              child: HopButton.secondary(
                label: 'Finish',
                onPressed: onContinue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
