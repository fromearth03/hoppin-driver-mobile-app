import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

/// Offer-takeover countdown ring — a wall-clock-derived arc with the numeric
/// seconds ALWAYS visible (Uber Base 'Timed button' rule: never the ring
/// alone). Driver-ux-motion §5 colour policy (05-03 spec pass, replacing the
/// interim 03-CONTEXT wall-window): the stroke stays accent until ~40% of
/// the window remains, ramps warn→error across the 40%→15% band, and holds
/// error below ~15% — ratio-based, so a future window-length change keeps
/// the urgency curve.
///
/// Time model (flutter-web-feasibility §2 — demo clock master, controller
/// slave): the internal AnimationController ONLY schedules frames; every
/// paint recomputes
/// `fraction = clamp((deadline − clock.now()) / (deadline − startedAt))`
/// from the wall clock, so the arc self-corrects after tab throttling or a
/// paused demo. Tests pin the clock with `withClock(Clock.fixed(t))`.
///
/// - Seconds render `ceil(remaining)` and update at 1Hz OUTSIDE the
///   per-frame ring repaint (ValueNotifier + ValueListenableBuilder).
/// - Final 3s: the inner content (child + seconds) breathes scale 1.0→1.03
///   on a 500ms reverse-repeat (§5).
/// - [child] (e.g. 'Accept') composes with the seconds below it; with no
///   child the seconds sit centered alone.
/// - Purely visual — expiry BUSINESS logic lives in the consuming
///   interactor. At/after the deadline this renders '0' and an empty arc.
class CountdownRing extends StatefulWidget {
  const CountdownRing({
    required this.deadline,
    required this.startedAt,
    this.size = 96,
    this.strokeWidth = 5,
    this.child,
    super.key,
  });

  /// When the offer expires (wall-clock instant).
  final DateTime deadline;

  /// When the countdown window opened — fixes the arc's 100% reference.
  final DateTime startedAt;

  /// Ring diameter.
  final double size;

  /// Arc stroke width.
  final double strokeWidth;

  /// Optional content composed above the seconds (e.g. an Accept label).
  final Widget? child;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing>
    with TickerProviderStateMixin {
  late final AnimationController _frameDriver;
  late final AnimationController _breathe;
  late final Animation<double> _breatheScale;
  late final ValueNotifier<int> _seconds;
  Timer? _ticker;
  bool _running = false;

  static const double _breathePeak = 1.03;

  /// §5: the final window in which the inner content breathes — resolved
  /// from [HoppinMotion.countdownBreatheWindow] before the first frame.
  Duration _breatheWindow = Duration.zero;

  Duration get _remaining {
    final r = widget.deadline.difference(clock.now());
    return r.isNegative ? Duration.zero : r;
  }

  int get _secondsLeft => (_remaining.inMilliseconds / 1000).ceil();

  @override
  void initState() {
    super.initState();
    _frameDriver = AnimationController(vsync: this);
    _breathe = AnimationController(vsync: this);
    _breatheScale = Tween<double>(begin: 1, end: _breathePeak).animate(
      CurvedAnimation(parent: _breathe, curve: Curves.easeInOut),
    );
    _seconds = ValueNotifier<int>(_secondsLeft);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.hoppin.motion;
    // The driver's duration is imperceptible — it only schedules frames;
    // the wall clock owns the value. countdownTotal keeps it token-fed.
    _frameDriver.duration = motion.countdownTotal;
    // §5: final-3s breathe, 500ms alternate — the slow token carries 500ms.
    _breathe.duration = motion.slow;
    _breatheWindow = motion.countdownBreatheWindow;
    if (!_running) {
      _running = true;
      // 1Hz seconds refresh — deliberately OUTSIDE the per-frame ring
      // repaint, on the secondsTick token cadence.
      _ticker = Timer.periodic(motion.secondsTick, (_) => _tick());
      _frameDriver.repeat();
      _syncBreathe();
    }
  }

  void _tick() {
    _seconds.value = _secondsLeft;
    _syncBreathe();
  }

  void _syncBreathe() {
    final remaining = _remaining;
    final shouldBreathe =
        remaining > Duration.zero && remaining <= _breatheWindow;
    if (shouldBreathe && !_breathe.isAnimating) {
      _breathe.repeat(reverse: true);
    } else if (!shouldBreathe && _breathe.isAnimating) {
      _breathe.stop();
      _breathe.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _frameDriver.dispose();
    _breathe.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    final secondsText = ValueListenableBuilder<int>(
      valueListenable: _seconds,
      builder: (context, s, _) => Text(
        '$s',
        style: widget.child == null
            ? hoppin.type.moneyTitle.copyWith(color: colors.textHi)
            : hoppin.type.numeral.copyWith(color: colors.textMid),
      ),
    );

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: CountdownRingPainter(
                deadline: widget.deadline,
                startedAt: widget.startedAt,
                strokeWidth: widget.strokeWidth,
                accent: colors.accent,
                warn: colors.warn,
                error: colors.error,
                track: colors.hairline,
                repaint: _frameDriver,
              ),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: _breatheScale,
              child: widget.child == null
                  ? secondsText
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        widget.child!,
                        SizedBox(height: hoppin.spacing.xs),
                        secondsText,
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter for [CountdownRing]. Public ONLY so tests can read
/// [debugLastFraction] / [debugLastStrokeColor] — not for direct use.
///
/// Every [paint] recomputes remaining time from `clock.now()`; the repaint
/// listenable merely schedules frames. Painters cannot read a BuildContext,
/// so the theme colours arrive pre-resolved.
class CountdownRingPainter extends CustomPainter {
  CountdownRingPainter({
    required this.deadline,
    required this.startedAt,
    required this.strokeWidth,
    required this.accent,
    required this.warn,
    required this.error,
    required this.track,
    super.repaint,
  });

  final DateTime deadline;
  final DateTime startedAt;
  final double strokeWidth;
  final Color accent;
  final Color warn;
  final Color error;
  final Color track;

  /// §5 colour policy: accent above 40% remaining, warn→error ramp across
  /// the 40%→15% band, solid error below 15%. Fractions of the window, so
  /// the urgency curve survives any window-length retune (45s today, ~15s
  /// once the Phase 6 pacing tweak lands).
  static const double _warnFraction = 0.40;
  static const double _errorFraction = 0.15;

  /// Written on every paint — the wall-clock purity probes for tests.
  double? debugLastFraction;
  Color? debugLastStrokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = deadline.difference(startedAt);
    final rawRemaining = deadline.difference(clock.now());
    final remaining = rawRemaining.isNegative ? Duration.zero : rawRemaining;
    final fraction = total <= Duration.zero
        ? 0.0
        : (remaining.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);

    final Color strokeColor;
    if (fraction > _warnFraction) {
      strokeColor = accent;
    } else if (fraction > _errorFraction) {
      final t =
          (_warnFraction - fraction) / (_warnFraction - _errorFraction);
      strokeColor = Color.lerp(warn, error, t)!;
    } else {
      strokeColor = error;
    }

    debugLastFraction = fraction;
    debugLastStrokeColor = strokeColor;

    final inset = strokeWidth / 2;
    final arcRect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawOval(arcRect, trackPaint);

    if (fraction > 0) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = strokeColor;
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CountdownRingPainter oldDelegate) {
    return oldDelegate.deadline != deadline ||
        oldDelegate.startedAt != startedAt ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.accent != accent ||
        oldDelegate.warn != warn ||
        oldDelegate.error != error ||
        oldDelegate.track != track;
  }
}
