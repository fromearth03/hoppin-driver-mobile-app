import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The designed unavailable-state for driver ACCOUNT DELETION (#43). **PS-06.**
///
/// 🔴 **This rung is unlike every other one in the driver app: it does not
/// merely disclose, it OFFERS THE WORKING ROUTE.** Its state is `MISSING_BE`
/// because there is no `DELETE /me` — but the action the driver takes is
/// **fully bound**. It files a real support ticket, into a real database, that
/// a real human reads and actions against the admin API.
///
/// A future reader WILL be tempted to make the button inert "for consistency"
/// with the other rungs. **Do not.** Art. 17 requires the route to exist, and
/// an inert button here would take a WORKING legal route and break it.
///
/// ## 🔴 The copy is legally constrained, and it must not promise erasure
///
/// Private-hire licensing and HMRC impose **minimum retention** on booking,
/// driver and financial records — and for a DRIVER that retention is heavier
/// than for a rider: a licensed operator must keep driver and booking records
/// for a statutory minimum. Full erasure would breach those obligations.
/// Anonymisation is the *correct* implementation, not a shortcoming: it
/// satisfies Art. 17 for the personal data while preserving the
/// legally-mandated records in a form no longer tied to a person.
///
/// So this widget must never say the data will be deleted. It says, plainly:
/// personal details are removed, the account is closed, and driving and payment
/// records are kept in anonymised form because the law requires it.
///
/// The four beats it carries:
///  1. **The right** — this is a legal right, not a favour.
///  2. **How it actually happens** — by hand, by a person, within one month.
///     One month is the statutory *maximum* (Art. 12(3)). It promises no faster
///     and never promises instant.
///  3. **What actually happens to the data** — anonymised, not erased.
///  4. **The honest delays** — active trips, open disputes, legal retention.
///     The right to erasure is **not absolute**; this is the law, not a fudge.
///
/// It is CONSTRUCTED by `delete_account_popup.dart`, presented from
/// `settings_screen.dart`. That mount site is what the Group C reachability
/// check looks for — a declared-but-never-constructed disclosure is dead code
/// wearing a compliance badge.
class DriverDeletionViaSupportNotice extends StatelessWidget {
  /// Creates the #43 data-rights disclosure.
  const DriverDeletionViaSupportNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    final body = hoppin.type.meta.copyWith(color: colors.textMid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. The right.
        Text(
          'You can ask us to close your driver account and remove your '
          'personal details. That is your right under UK data-protection law.',
          style: body,
        ),
        SizedBox(height: hoppin.spacing.md),

        // 2. How it actually happens. No euphemism, no automation theatre.
        Text(
          'We do this by hand today. Your request opens a support ticket and a '
          'person acts on it. We will come back to you within one month.',
          style: body,
        ),
        SizedBox(height: hoppin.spacing.md),

        // 3. 🔴 What actually happens to the data. This paragraph is the one
        //    that must never be softened into a promise of erasure.
        Text(
          'What that means: your personal details are removed and your account '
          'is closed. Your driving, licensing and payment records are kept in '
          'anonymised form — with nothing in them that identifies you — '
          'because taxi licensing and tax law require an operator to keep them '
          'for a set period.',
          style: body,
        ),
        SizedBox(height: hoppin.spacing.md),

        // 4. The honest delays. This is the law, not a fudge — the right to
        //    erasure is not absolute.
        Text(
          'It can take longer if you have a trip in progress, an open dispute '
          'with us, or where the law requires us to hold on to something for '
          'a while.',
          style: body,
        ),
      ],
    );
  }
}
