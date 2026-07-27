import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The #45 rung, in the DRIVER's voice.
///
/// The gap is shared with the rider; the DISCLOSURE is not — that is the whole
/// reason `SeamEntry` carries a LIST of disclosures. The rider's rung says "we
/// can't connect you to your driver". The driver's says the true thing from
/// this side of the windscreen, and it hands over the channel that actually
/// works.
///
/// There is no `POST /rides/:id/call` proxy and no masked-number field on any
/// payload (#45). With no proxy to mask through, a "call" button could only
/// ever dial a rider's PERSONAL number — the precise exposure masked calling
/// exists to prevent, and a locked prohibition. So this rung takes the place of
/// the live status line the Figma draws ("Calling…", "Ringing…") and says the
/// true thing instead.
///
/// 🔴 IT MUST OFFER THE EXIT. A rung that names a hole and leaves the driver
/// standing in it is half-honest. Chat is BOUND (`POST /rides/:id/messages`), so
/// this offers it as a primary action — the rider's own CallUnavailableState set
/// this precedent and Group D checks it.
class DriverCallUnavailableState extends StatelessWidget {
  /// Creates the #45 masked-voice degrade rung.
  const DriverCallUnavailableState({required this.onOpenChat, super.key});

  /// Opens the BOUND chat thread — the working alternative this rung offers.
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return HopEmptyState(
      compact: true,
      headline: 'Calling is not live yet',
      supporting:
          'Number-masked calling is on the way. Until it lands we will not '
          "connect you through an unmasked line — your number and the rider's "
          'stay private. Message them instead; it reaches them straight away.',
      actionLabel: 'Message rider',
      onAction: onOpenChat,
    );
  }
}
