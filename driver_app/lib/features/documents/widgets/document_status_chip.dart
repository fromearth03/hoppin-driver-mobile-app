import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// Renders the SERVER'S OWN `verification_status` string. Nothing else.
///
/// 🔴 READ THIS BEFORE YOU "IMPROVE" THIS WIDGET.
///
/// The Figma shows a green **"Valid"** badge. That word does not exist in the
/// backend's vocabulary — `DOCS/04` (L174) documents exactly ONE status
/// (`pending_review`) and says admin review moves a document on from there,
/// **without ever saying where to**. So we do not know the enum (seam #83) and
/// we may not invent it.
///
/// Rendering "Valid" over a `pending_review` DVLA licence tells a driver they
/// may LEGALLY WORK when we do not know that. A driver who reads it and takes a
/// fare is uninsured and unlicensed on our word. It carries operator licensing
/// exposure, and it is the same species of defect as the fabricated
/// accessibility UUID that once told a wheelchair user their vehicle was
/// booked.
///
/// So: this widget takes a `String status` and renders THAT STRING. It may
/// prettify (`pending_review` → `Pending review`) because that is a pure,
/// reversible function of the server's token. It may NOT map, translate,
/// bucket, or upgrade it. An unrecognised status renders AS ITSELF — because an
/// unpublished enum means we are IGNORANT, not that the value is invalid.
class DocumentStatusChip extends StatelessWidget {
  /// Creates a chip over the server's raw `verification_status` token.
  const DocumentStatusChip({required this.status, super.key});

  /// The raw server token. Not an enum. **Never an enum.**
  final String status;

  /// The ONE status word the backend has actually published (`DOCS/04` L174).
  /// It is the only token this widget is entitled to have an opinion about.
  static const String publishedStatus = 'pending_review';

  /// `pending_review` → `Pending review`. A pure, reversible transform of the
  /// server's token: underscores to spaces, first letter up. Nothing is
  /// substituted, nothing is bucketed, nothing is upgraded.
  static String prettify(String status) {
    final spaced = status.trim().replaceAll('_', ' ');
    if (spaced.isEmpty) return status;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    // 🔴 EVERY STATUS GETS THE SAME NEUTRAL TONE — including the ones we have
    // never heard of. A GREEN CHIP IS A CLAIM: it says "this document is fine,
    // you may work". We are only entitled to make that claim when the platform
    // makes it, and the platform has never published the word for it. So we
    // make no claim, in either direction: an unknown token is not green and it
    // is not red either, because a rejection we invented would be just as
    // false as an approval we invented.
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: hoppin.spacing.sm,
        vertical: hoppin.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(hoppin.radii.pill),
        border: Border.all(color: colors.hairline),
      ),
      child: Text(
        prettify(status),
        style: hoppin.type.metaSmall.copyWith(color: colors.textMid),
      ),
    );
  }
}
