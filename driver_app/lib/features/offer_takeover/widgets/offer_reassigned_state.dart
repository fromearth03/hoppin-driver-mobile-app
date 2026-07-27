import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// 🔴 THE 409 `OFFER_EXPIRED` STATE — AND IT IS AN APOLOGY, NOT AN ERROR.
///
/// The driver tapped ACCEPT inside the window. The network was slow, and the
/// round-trip lost the race — someone else got the ride, or the world moved on.
/// **They did their job; we didn't.** A red toast on a dead card would blame
/// them for our latency and then strand them on a card that will never do
/// anything again.
///
/// So this is deliberately quiet: neutral tones, NO red, NO "error", NO
/// "failed". It names what happened plainly, and it is a FORWARD EXIT — the
/// takeover dismisses on a short beat (the same rhythm the quiet expired note
/// uses) and the driver lands back on the dashboard, still online, ready for
/// the next one.
class OfferReassignedState extends StatelessWidget {
  const OfferReassignedState({super.key});

  /// The non-blaming copy. No apology asked of the driver, because none is
  /// owed by them.
  static const String message =
      "That ride went to another driver. You're still online — the next one's "
      'on its way.';

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hoppin.spacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 40,
              color: colors.textMid,
            ),
            SizedBox(height: hoppin.spacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              // Neutral on-surface tone — the same register as the quiet
              // 'Offer expired' note, never the error token.
              style: hoppin.type.title.copyWith(color: colors.textMid),
            ),
          ],
        ),
      ),
    );
  }
}
