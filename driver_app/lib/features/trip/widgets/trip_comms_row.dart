import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../map/map_builder.dart';
import '../stuck/stuck_exit_sheet.dart';
import '../trip_nav_handoff.dart';

/// Navigate, Chat, Call and "I'm stuck", side by side on the runner card.
///
/// 🔴 ONE TAP EACH, LARGE TARGETS, AND THEY STAY LIVE IN MOTION.
///
/// Do NOT wrap these in TypingLockedInMotion. A cradled phone is legal to touch
/// — that is exactly how every Uber and Bolt driver taps Accept and Arrived at
/// the wheel — and a one-tap button is a glance, not a distraction. What goes
/// away at speed is the KEYBOARD, and there is no keyboard here. A driver
/// handing off to Google Maps is the in-motion case by definition.
///
/// 15-00's gate has a SIDE B that fails RED if these are suppressed. That side
/// exists because the first draft of this milestone tried to ban them, and an
/// app that makes a driver pull over to tap "Arrived" is an app that gets
/// uninstalled — after which they coordinate on WhatsApp, in their hand, which
/// is the actual offence.
class TripCommsRow extends ConsumerWidget {
  /// Creates the comms row for [rideId].
  const TripCommsRow({required this.rideId, super.key});

  /// The ride these controls act on.
  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    // OT-16: the current leg's hand-off target. Null (both geo seams null — the
    // live case) hides Navigate, the same degradation the map's own chip uses.
    final destination = ref.watch(
      tripMapInteractorProvider(rideId).select((s) => s.destination),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navigate → hands off to Google Maps turn-by-turn for the current leg.
        // A full-width primary, because navigation IS the driver's main task
        // while heading somewhere — and it earns the room three equal comms
        // buttons plus a fourth could not give it. ONE TAP, UNWRAPPED: it stays
        // live in motion; a driver navigating is exactly the in-motion case,
        // and it is not text entry. Hidden when there is no honest destination
        // (both geo seams null — the live case), the same designed degradation
        // the map's own objective chip uses.
        if (destination != null) ...[
          HopButton.secondary(
            label: 'Navigate',
            icon: Icons.navigation_outlined,
            onPressed: () => ref.read(navHandoffProvider)(
              destLat: destination.lat,
              destLng: destination.lng,
            ),
          ),
          SizedBox(height: hoppin.spacing.sm),
        ],
        // 🔴 THREE ACROSS, AND THE LABELS ARE SIZED TO THE COLUMN THEY GET.
        //
        // The card is inset by the page gutter (24 a side) and its own padding
        // (lg, 16 a side), so each third is ~66pt on a 390pt phone and ~43pt on
        // a 320pt one. HopButton lays its label out in a CENTRED,
        // NON-SHRINKING Row at `type.button` (18pt) behind `spacing.lg` side
        // padding — so the row overflowed on every screen size, in every
        // working phase. That is the black-and-yellow stripe across the bottom
        // of a live trip.
        //
        // The fix is horizontal, NOT vertical: this row must stay ONE row.
        // Moving the stuck exit onto a second full-width row does fix the
        // width, but it adds ~60pt of card height, and the card is already at
        // its vertical ceiling at arrivedAtPickup (the clock + the #44 policy
        // rung) — it simply trades a horizontal overflow for a bottom one.
        Row(
          children: [
            // Chat → `/trip/:id/chat` (15-01, BOUND). ONE TAP, UNWRAPPED — it
            // stays live in motion; it is NOT text entry. `maybeOf` so a
            // routerless test harness (15-00's motion gate boots one) never
            // crashes on the tap — in production the router is always present.
            Expanded(
              child: _CommsAction(
                label: 'Chat',
                onTap: () =>
                    GoRouter.maybeOf(context)?.push('/trip/$rideId/chat'),
              ),
            ),
            SizedBox(width: hoppin.spacing.sm),
            // Call → `/trip/:id/call` (15-02, inert on #45, disclosed on
            // arrival). Green fill per Figma: the phone colour is the
            // universal "call is possible" signal even on a disclosed seam.
            Expanded(
              child: _CommsAction(
                label: 'Call',
                tone: _CommsTone.call,
                onTap: () =>
                    GoRouter.maybeOf(context)?.push('/trip/$rideId/call'),
              ),
            ),
            SizedBox(width: hoppin.spacing.sm),
            // I'm stuck → the trapped-driver exit. One tap opens the sheet.
            Expanded(
              child: _CommsAction(
                label: "I'm stuck",
                onTap: () => showStuckExitSheet(context, rideId: rideId),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Which semantic fill a comms target wears.
enum _CommsTone {
  /// Card fill, accent border and label — Chat and I'm stuck.
  quiet,

  /// Success fill, onAccent label — Call. The phone colour is the universal
  /// "call is possible" signal even on a disclosed seam.
  call,
}

/// One large, glanceable comms target.
///
/// 🔴 NO LEADING ICON. [HopButton] lays its icon and label out in a CENTRED,
/// NON-SHRINKING Row at `type.button` (18pt) behind `spacing.lg` side padding.
/// Inside the runner card's narrow columns even a short label is tight, and a
/// 20pt icon plus its gap was enough to push every one of these over. The words
/// are what the driver reads at a glance anyway.
///
/// 🔴 IT MUST STAY A HopButton. 15-00's motion gate (side B) walks this row
/// looking for a `HopButton` ancestor of each of "Chat", "Call" and "I'm stuck"
/// and fails RED if one is missing — that gate is what stops a future change
/// suppressing these controls at speed. A hand-rolled Material/InkWell
/// look-alike renders identically and silently fails that check, so the fix for
/// a layout problem here is never to leave the component; it is to give the
/// component room (see the two-row layout above).
class _CommsAction extends StatelessWidget {
  const _CommsAction({
    required this.label,
    required this.onTap,
    this.tone = _CommsTone.quiet,
  });

  final String label;
  final VoidCallback onTap;
  final _CommsTone tone;

  @override
  Widget build(BuildContext context) {
    return switch (tone) {
      _CommsTone.quiet => HopButton.secondary(label: label, onPressed: onTap),
      _CommsTone.call => HopButton.green(label: label, onPressed: onTap),
    };
  }
}
