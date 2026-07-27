import 'package:flutter/material.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../eligibility_state.dart';

/// The four rungs, off the SERVER'S REAL `expires_at` — one of the very few
/// driver features that is FULLY BOUND today and has never been read.
///
/// 🔴 EVERY RUNG NAMES THE DOCUMENT. That is the entire point of it.
///
/// "You can't go online" is not a message, it is a riddle with eight answers. A
/// driver who reads it and does not know WHICH document to fix has been told
/// nothing useful — so they will tap GO again to find out, and get the same
/// riddle, and eventually drive to a rank at 5am to find out the hard way. The
/// rung says: **"Your MOT certificate expired on 3 Jun."** Then they know, and
/// they can fix it, and they can do it from their sofa on Sunday rather than in
/// a car park.
///
/// The tones are asymmetric on purpose: [ExpiryRung.informational] (T-30d) and
/// [ExpiryRung.prominent] (T-7d) are NOTICES and change nothing.
/// [ExpiryRung.lastDay] (T-1d) is loud and STILL changes nothing — they can
/// legally work today, and taking that away costs a real driver a real shift for
/// no reason. Only [ExpiryRung.expired] blocks.
///
/// 🔴 EVERY RUNG IN THE LIST RENDERS — never only the worst one. A driver
/// fixing their MOT must not tap GO, get blocked *again*, and only then
/// discover the insurance was also about to lapse. Tell them everything you
/// know, once.
///
/// Visually this is the [LocationUnavailableBanner] family, deliberately: a
/// driver who has learnt what that banner means should read this one instantly.
class DocumentExpiryLadder extends StatelessWidget {
  /// Creates the expiry ladder over [expiries] (worst rung first).
  const DocumentExpiryLadder({required this.expiries, super.key});

  /// Every document within 30 days of its server-issued expiry, worst first.
  final List<DocumentExpiry> expiries;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in expiries) ...[
          _rung(e),
          SizedBox(height: hoppin.spacing.sm),
        ],
      ],
    );
  }

  Widget _rung(DocumentExpiry e) {
    final date = formatShortDateTime(e.expiresAt);
    return switch (e.rung) {
      // 🔴 THE BLOCKING RUNG. It names the document, and it names the date the
      // server says it lapsed — because "you can't go online" on its own is the
      // failure mode this whole widget exists to delete.
      ExpiryRung.expired => HopBanner.error(
          message: 'Your ${e.label} expired on $date. You cannot go online '
              'until a valid one is approved.',
        ),
      // The last legal day. Unmissable — and it stops nothing.
      ExpiryRung.lastDay => HopBanner.error(
          message: 'Your ${e.label} expires on $date — today is the last day '
              'you can work on it.',
        ),
      ExpiryRung.prominent => HopBanner.notice(
          message: 'Your ${e.label} expires on $date. Renew it soon to keep '
              'working.',
        ),
      ExpiryRung.informational => HopBanner.notice(
          message: 'Your ${e.label} expires on $date.',
        ),
    };
  }
}
