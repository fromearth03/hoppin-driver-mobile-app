import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The Successful frame, re-purposed — and **re-worded**.
///
/// 🔴 **THIS SCREEN MUST NOT TELL THE DRIVER THEY ARE READY TO DRIVE, BECAUSE IT
/// CANNOT KNOW.** Eligibility is the SERVER'S decision and only the server's:
/// `POST /drivers/me/online` is compliance-gated and answers `403 NOT_ELIGIBLE`
/// when the documents do not satisfy it. The app never sees that verdict until
/// the driver taps GO.
///
/// So every phrase the Figma's success frames reach for is forbidden here:
///
/// - **"You're all set"** — we do not know that. An admin has not looked yet.
/// - **"You can now go online"** — we especially do not know that, and it is the
///   most expensive sentence on the screen. A driver who reads it drives to a
///   busy area, taps GO, and is refused. They have now spent fuel and an hour of
///   a shift on a promise this screen had no standing to make.
/// - **A green tick over the whole flow** — the tick belongs to the upload, not
///   to the outcome.
///
/// What IS true, and what this screen says: the documents are with the team, a
/// human will review them, and we will let them know. That is the entire content
/// of the honest version, and it is enough.
class OnboardingComplete extends StatelessWidget {
  /// Creates the completion frame.
  const OnboardingComplete({
    required this.onGoToDashboard,
    required this.onOpenDocuments,
    super.key,
  });

  /// Terminal exit to the dashboard.
  final VoidCallback onGoToDashboard;

  /// Back out to `/documents` — for anything still outstanding.
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: colors.accent,
        ),
        SizedBox(height: hoppin.spacing.gutter),
        Text(
          "Your documents are with our team",
          textAlign: TextAlign.center,
          style: hoppin.type.h1.copyWith(color: colors.textHi),
        ),
        SizedBox(height: hoppin.spacing.md),
        Text(
          // Deliberately NOT "you're all set" and NOT "you can now go online".
          // Only the server decides whether this driver is eligible, and it
          // decides it at the moment they tap GO — not here.
          "We'll review everything you've uploaded and let you know as soon as "
          "you're cleared to start taking rides.",
          textAlign: TextAlign.center,
          style: hoppin.type.meta.copyWith(color: colors.textMid),
        ),
        SizedBox(height: hoppin.spacing.xl),
        HopButton.primary(
          label: 'Go to dashboard',
          onPressed: onGoToDashboard,
        ),
        SizedBox(height: hoppin.spacing.md),
        HopButton.ghost(
          label: 'Review my documents',
          onPressed: onOpenDocuments,
        ),
      ],
    );
  }
}
