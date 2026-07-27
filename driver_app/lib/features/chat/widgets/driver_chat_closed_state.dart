import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The designed `409 CHAT_CLOSED` TERMINAL state for the driver.
///
/// `POST /rides/:id/messages` answers `409 CHAT_CLOSED` once the ride ends
/// (docs/04). That is PERMANENT, not transient: the thread will never accept
/// another message. This panel stands **in place of** the composer and the
/// [DriverChatTemplates] chip row once that 409 lands — both are REMOVED from
/// the tree, not disabled beneath a toast. The thread above stays readable: the
/// channel closes, the conversation does not disappear.
///
/// 🔴 It carries a FORWARD EXIT. A disclosure that strands the driver is only
/// half-honest — the rider's `CallUnavailableState` set this precedent. The
/// driver is given a way back to the trip, never left on a dead surface.
///
/// This is a designed terminal for a documented `409` on a BOUND endpoint — it
/// is NOT a seam, NOT a disclosure of a missing endpoint.
class DriverChatClosedState extends StatelessWidget {
  /// Creates the closed-chat terminal panel.
  ///
  /// [onExit] is the forward exit — the host wires it to return the driver to
  /// their trip.
  const DriverChatClosedState({this.onExit, super.key});

  /// The forward exit intent. Null renders the panel without the button (the
  /// panel is never a dead end when the host provides it).
  final VoidCallback? onExit;

  /// The headline the driver reads. Exposed so the contract test can assert the
  /// exact copy the terminal state promises to show.
  static const String headline = 'This conversation is closed';

  /// The supporting line — says what happened.
  static const String supporting =
      'The trip has ended, so messaging your rider is no longer available. '
      'You can still read this conversation.';

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Container(
      width: double.infinity,
      color: colors.canvas,
      padding: EdgeInsets.symmetric(
        horizontal: hoppin.spacing.gutter,
        vertical: hoppin.spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            headline,
            textAlign: TextAlign.center,
            style: hoppin.type.titleSmall.copyWith(color: colors.textHi),
          ),
          SizedBox(height: hoppin.spacing.xs),
          Text(
            supporting,
            textAlign: TextAlign.center,
            style: hoppin.type.meta.copyWith(color: colors.textMid),
          ),
          if (onExit != null) ...[
            SizedBox(height: hoppin.spacing.md),
            HopButton.secondary(
              label: 'Back to trip',
              onPressed: onExit,
            ),
          ],
        ],
      ),
    );
  }
}
