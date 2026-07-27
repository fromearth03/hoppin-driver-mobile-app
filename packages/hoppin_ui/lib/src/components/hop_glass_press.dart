import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

/// Press response for a pane of [HopGlass] — the weight you feel when you push
/// on a slab of glass.
///
/// 🔴 **Why this is a separate file from `hop_glass.dart`.**
///
/// `motion_guards_test` greps `hop_glass.dart` TEXTUALLY for `Animation<`,
/// `Tween` and `AnimatedBuilder`, and that ban is correct — but read its stated
/// reason (motion_guards_test:151-156): it exists so the SIGMA never animates,
/// because an animated sigma re-rasterises the backdrop every single frame and
/// hands the budget exactly the bill the blanket blur ban existed to prevent.
///
/// An animated *overlay* is not an animated *backdrop*. Scaling a pane and
/// tinting it costs a transform and a paint-alpha on a layer that is already
/// composited; the `BackdropFilter` underneath keeps its fixed geometry and its
/// cached rasterisation, which is the property the rule is actually protecting.
///
/// So the guard is not weakened and not narrowed — it is OBEYED, by keeping the
/// blur site free of animators and putting the motion in a sibling that composes
/// it. The blur stays in one file; the press lives here; the rule keeps meaning
/// exactly what it says.
///
/// (This also uses IMPLICIT animations, which carry none of the banned strings
/// anyway. That is a happy accident and not the argument — the argument is that
/// the backdrop never re-rasterises.)
///
/// 🔴 **Only wrap glass that is actually PRESSABLE.** A passive chrome bar with a
/// press response is a lie about affordance: it invites a tap that does nothing.
class HopGlassPress extends StatefulWidget {
  /// Wraps [child] in a weighted press response.
  const HopGlassPress({
    required this.child,
    this.onTap,
    this.borderRadius,
    super.key,
  });

  /// The pane being pressed — normally a `HopGlass`.
  final Widget child;

  /// What the press does. When null the pane is inert and NO press response is
  /// rendered: a surface only depresses if pressing it means something.
  final VoidCallback? onTap;

  /// The pane's corners, so the press tint follows the same shape. Matches the
  /// glass it wraps; a square tint under a pill is visible at the corners.
  final BorderRadius? borderRadius;

  @override
  State<HopGlassPress> createState() => _HopGlassPressState();
}

class _HopGlassPressState extends State<HopGlassPress> {
  bool _down = false;

  /// The depressed scale.
  ///
  /// 1.5% and not the 5-10% a button uses. This is a PANE of glass, not a
  /// rubber key: a big surface scaling visibly reads as a card shrinking, which
  /// is a cheap effect. Glass is heavy and barely moves — the eye reads the
  /// small displacement as MASS. Restraint is the whole point.
  static const double _pressedScale = 0.985;

  void _setDown(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final motion = hoppin.motion;

    // Inert glass gets no press response at all — see the note on [onTap].
    if (widget.onTap == null) {
      return widget.child;
    }

    final radius = widget.borderRadius ?? BorderRadius.zero;

    return GestureDetector(
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: widget.onTap,
      // The pane must keep taking pointers where it paints, and only there.
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? _pressedScale : 1.0,
        // `quick` (250ms), not the snappier `fade` (100ms). A press that
        // completes in 100ms reads as ELECTRONIC — a state flipping. Glass has
        // weight, and weight takes time to move: the slower settle is what makes
        // the pane feel like it has mass behind it rather than a highlight state.
        duration: motion.quick,
        // easeOut, never a spring. Glass does not bounce; a pane that overshoots
        // its rest position is plastic. It decelerates into place and stops.
        curve: motion.easeOut,
        child: AnimatedContainer(
          duration: motion.quick,
          curve: motion.easeOut,
          decoration: BoxDecoration(
            borderRadius: radius,
            // The press DARKENS the pane fractionally, using the pane's own
            // under-rim colour — the same navy/near-black that draws its far
            // face. Pressing glass into a surface is the whole slab moving into
            // its own shadow, so the tint that shows is the shadow it already
            // has. A grey wash here would read as a disabled state; a fresh
            // colour would read as a hover effect from a different design
            // system.
            color: _down
                ? colors.glassUnderRim.withValues(
                    alpha: colors.glassUnderRim.a * 0.5,
                  )
                : colors.glassUnderRim.withValues(alpha: 0),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
