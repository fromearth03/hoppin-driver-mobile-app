import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The #44 rung: we show how long you have been waiting, and we DO NOT show a
/// waiting charge — because the platform has not set one.
///
/// There is no free-wait window and no per-minute rate anywhere in the product
/// (#44). The elapsed clock beside this rung is honest; the POLICY behind it is
/// a hole, and the driver is told so. Without this rung the clock silently
/// implies a charge that does not exist — which is the exact lie about a
/// self-employed person's pay this surface must never tell.
///
/// 🔴 It routes to the stuck exit. A rung that names a hole and leaves the
/// driver sitting in it is half-honest — and this particular driver is
/// literally sitting in it, outside a pickup, with no cancel (#1).
class WaitingPolicyUnavailable extends StatelessWidget {
  /// Creates the #44 waiting-policy disclosure.
  const WaitingPolicyUnavailable({required this.onOpenStuck, super.key});

  /// Opens the stuck exit — the one bound door out of a no-show.
  final VoidCallback onOpenStuck;

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
          // Kept to two lines deliberately. At arrivedAtPickup this card
          // carries its tallest payload — rider row, spine, clock, this rung,
          // the action zone and the comms row — and on a 320-360pt phone that
          // stack exceeds the viewport. This copy is the only part that can
          // yield without losing meaning or a control: the claim it must make
          // is "the clock is not a charge", and it still makes it.
          Text(
            "This is how long you've been waiting — not a waiting charge. "
            "The platform hasn't set one.",
            style: hoppin.type.labelSmall.copyWith(color: colors.textMid),
          ),
          SizedBox(height: hoppin.spacing.sm),
          // 🔴 A TEXT AFFORDANCE, NOT A HopButton — because this label cannot
          // be allowed to overflow and HopButton's label cannot yield.
          //
          // HopButton lays its label out in a centred Row at `type.button`
          // (18pt) with `spacing.lg` side padding and NO shrink behaviour: the
          // Text is unconstrained, so when the label is longer than the box the
          // Row overflows rather than ellipsising. Measured here it wanted
          // ~347px inside a rung ~182-273px wide on every phone probed — a
          // black-and-yellow stripe across the one exit a stranded driver has.
          // `expand: false` does not help; it hugs the label, and the label is
          // the thing that is too big.
          //
          // So this is an InkWell over a Text that CAN yield (maxLines +
          // ellipsis), sized to the 44pt touch floor a driver needs in a
          // cradle. Same accent role, same one tap, same destination — it just
          // cannot break the layout. (HopButton gaining a shrinking label would
          // be the better fix; that is a hoppin_ui change, reported not made.)
          Semantics(
            button: true,
            child: InkWell(
              onTap: onOpenStuck,
              borderRadius: BorderRadius.circular(hoppin.radii.control),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: hoppin.spacing.xs),
                    child: Text(
                      // One line: two lines cost ~20pt in the phase where the
                      // card is already over budget on a small phone.
                      "Rider isn't coming?",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: hoppin.type.label.copyWith(color: colors.accent),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
