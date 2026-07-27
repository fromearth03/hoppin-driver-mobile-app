import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// The honest waiting clock. It COUNTS UP and it means exactly one thing:
/// how long you have been here.
///
/// 🔴 IT IS NOT MONEY AND IT MUST NEVER LOOK LIKE MONEY. No currency mark, no
/// rate, no accruing figure, no threshold, no "wait charge starts in…". (The
/// pound sign is spelled nowhere in this file on purpose — the phase gate greps
/// `lib/` for it, and a docstring explaining the ban must not be what trips the
/// gate.) There is no
/// waiting policy in this product (#44) — no window, no rate, no trigger — so
/// any number implying the driver is being PAID to sit here is invented, and
/// a driver will believe it, and then be short-paid, and be right to be angry.
///
/// Recomputes from `clock.now()` on every tick. It NEVER trusts that a timer
/// fired (PL-03) — a backgrounded Android process gets its timers clamped, and
/// an elapsed clock built by counting ticks would silently run slow and quietly
/// under-report the driver's own wait. The timer here ONLY calls `setState`;
/// the value is always `clock.now().difference(since)`.
class WaitingElapsed extends StatefulWidget {
  /// Creates the count-up waiting clock anchored to [since].
  const WaitingElapsed({required this.since, super.key});

  /// The local arrive stamp the elapsed time is measured from.
  final DateTime since;

  @override
  State<WaitingElapsed> createState() => _WaitingElapsedState();
}

class _WaitingElapsedState extends State<WaitingElapsed> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The timer is a REPAINT trigger, nothing more. The displayed value is
    // recomputed from the clock every build, so a clamped or skipped tick
    // costs a frame's smoothness, never a second of the driver's wait.
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    // Clamp negatives to zero: a stamp fractionally ahead of the clock (a
    // rebuild in the same instant) must never render a minus sign.
    var elapsed = clock.now().difference(widget.since);
    if (elapsed.isNegative) elapsed = Duration.zero;

    // `min` sized the row to its children and let a 28pt clock push the label
    // past the card's inner width on narrow phones (a 26px RenderFlex overflow
    // at 320-360pt). The row is a full-width rung inside a fixed-width card, so
    // it takes the width it is given and lets the LABEL yield: the clock is the
    // fact being read and must never be the thing that gets clipped.
    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 20, color: colors.textMid),
        SizedBox(width: hoppin.spacing.sm),
        // Plainly "Waiting". Not "Wait time", not "Waiting charge".
        Flexible(
          child: Text(
            'Waiting',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hoppin.type.label.copyWith(color: colors.textMid),
          ),
        ),
        SizedBox(width: hoppin.spacing.sm),
        // The count-UP clock, on its own so it reads as exactly "03:14" — big,
        // tabular, high-contrast (a glance, not a read; SF-02). It is a
        // DURATION and it never wears a currency mark.
        Text(
          _format(elapsed),
          style: hoppin.type.headline.copyWith(
            color: colors.textHi,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
