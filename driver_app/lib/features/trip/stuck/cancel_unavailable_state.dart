import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// 🔴 THE MOST IMPORTANT RUNG IN THE DRIVER APP.
///
/// `PATCH /rides/:id/cancel` requires a `reason_id` uuid that NO ENDPOINT
/// ANYWHERE LISTS (#1). There is no `GET /cancellation-reasons`. So EVERY
/// cancel call 400s — and `actor_type: "driver"` hits the identical wall. The
/// driver cannot cancel. Not "cannot cancel easily". CANNOT.
///
/// And there is no no-show mechanism at all (#44). So a driver outside an empty
/// house, with a rider who is not coming, is TRAPPED in a live trip: they can
/// sit there, or they can force-quit and leave the ride open server-side with
/// themselves still attached to it.
///
/// The Figma's answer is a red banner reading "You cannot cancel a ride after
/// accepting it" — while its own "You owe" sheet itemises a CANCELLATION
/// PENALTY. The design contradicts itself and the truth is worse than either
/// half of it.
///
/// 🔴 SO WE DRAW NO CANCEL BUTTON. A button that 400s is worse than no button:
/// it teaches the driver the app is broken and leaves them exactly as trapped.
/// We say the true thing, and we hand them the one door that IS bound.
class CancelUnavailableState extends StatelessWidget {
  /// Creates the #1 cancel-unavailable disclosure.
  const CancelUnavailableState({super.key});

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(hoppin.spacing.md),
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(hoppin.radii.control),
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "We can't cancel this ride from the app yet",
            style: hoppin.type.titleSmall.copyWith(color: colors.textHi),
          ),
          SizedBox(height: hoppin.spacing.xs),
          // The truth, plainly, and it never claims a cancellation is happening.
          // "support ticket" is said in those words below — it lands in the
          // ticket queue and it does NOT move the ride or any balance.
          Text(
            "The platform hasn't given us a way to. If your rider isn't "
            'coming, message them, or open a support ticket and we\'ll sort '
            'it out with you.',
            style: hoppin.type.label.copyWith(color: colors.textMid),
          ),
        ],
      ),
    );
  }
}
