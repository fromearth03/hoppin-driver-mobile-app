import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The **seam #83 rung** — the `verification_status` enum is UNPUBLISHED.
///
/// 🔴 THIS IS MOUNTED UNCONDITIONALLY, AND THAT IS THE POINT.
///
/// Every other unavailable-state in this app hangs off a null branch: the seam
/// answers nothing, so the rung renders. This one does not, because the gap is
/// not sometimes-there. `DOCS/04` (L174) publishes exactly ONE status word —
/// `pending_review` — and says admin review moves a document on from there
/// **without ever saying where to**. That is true on every request, forever,
/// until the backend publishes the enum. A conditional rung over a permanent
/// gap would simply never render.
///
/// What it protects: the Figma renders a green **"Valid"** badge. That word is
/// not in the backend's vocabulary. Shown over a `pending_review` DVLA licence
/// it tells a driver **they may legally work** when the platform has said no
/// such thing — and a driver who reads it and takes a fare is uninsured and
/// unlicensed on our word. So the app renders the server's own token verbatim
/// (see `DocumentStatusChip`), and this rung tells the driver WHY the words
/// they are reading are the platform's and not ours.
///
/// The promise in the copy is the load-bearing sentence: **we will never tell
/// you a document is valid unless the platform says so in those words.**
class DocumentVocabularyUnavailable extends StatelessWidget {
  /// Creates the #83 document-vocabulary rung.
  const DocumentVocabularyUnavailable({this.onContactSupport, super.key});

  /// The forward exit — a driver who needs to know whether they may work has
  /// to be able to ask a human. Null hides it (bare-harness use).
  final VoidCallback? onContactSupport;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Container(
      padding: EdgeInsets.all(hoppin.spacing.md),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(hoppin.radii.card),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What these statuses mean',
            style: hoppin.type.bodyMedium.copyWith(color: colors.textHi),
          ),
          SizedBox(height: hoppin.spacing.xs),
          Text(
            'Each status above is the word our review team recorded against '
            'your document — we show it to you exactly as they wrote it, and '
            'we do not translate it.\n\n'
            'We will never tell you a document is valid unless the platform '
            'says so in those words. If you need to know whether you are '
            'clear to work, ask us.',
            style: hoppin.type.metaSmall.copyWith(color: colors.textMid),
          ),
          if (onContactSupport != null) ...[
            SizedBox(height: hoppin.spacing.sm),
            HopButton.ghost(
              label: 'Ask about my documents',
              onPressed: onContactSupport,
            ),
          ],
        ],
      ),
    );
  }
}
