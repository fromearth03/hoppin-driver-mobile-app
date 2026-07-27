import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

/// The map-less live-trip centrepiece — labelled origin/destination nodes
/// joined by a continuously-filling line whose filled portion carries the
/// travelling charge-line pulse (the Blackcab graft, 05-CONTEXT motif 2),
/// with a car marker riding the progress fraction and a word waypoint above
/// the track ("Passing Heath Town").
///
/// Pure presentation: progress in, pixels out. The consuming riblet computes
/// the journey fraction; the strip only eases BETWEEN the values it is given
/// (short ease-out retarget) so consumer jumps read as continuous fill —
/// Deliveroo's "a momentary glance is enough".
///
/// Completion contract:
/// - When [complete] flips false→true the fill pins to 100% and the
///   destination node blooms exactly once (expanding ring + fill-in) — the
///   one rider celebration. Re-supplying `complete: true` never re-triggers.
/// - Mounting the strip already complete (the receipt case) renders the full
///   strip statically: no bloom replay, no running pulse.
/// - While complete, the charge pulse rests — the celebration is the bloom;
///   afterwards the strip is calm, so receipts never burn frames.
///
/// Web budget: ONE CustomPainter on one canvas layer inside a
/// [RepaintBoundary]; every fade rides a paint colour's alpha; no blur, no
/// per-frame shadows. Labels and the waypoint are ordinary [Text] widgets
/// OUTSIDE the canvas so text never repaints per-frame.
class RouteStrip extends StatefulWidget {
  const RouteStrip({
    required this.originLabel,
    required this.destinationLabel,
    required this.progress,
    this.activeWaypoint,
    this.complete = false,
    this.showCarMarker = true,
    super.key,
  });

  /// Pickup point name, e.g. 'Wolverhampton Rail Station'.
  final String originLabel;

  /// Destination name, e.g. 'New Cross Hospital'.
  final String destinationLabel;

  /// Journey fraction 0.0..1.0, consumer-computed. The strip eases between
  /// supplied values; it never invents progress of its own.
  final double progress;

  /// Word waypoint shown above the track, e.g. 'Passing Heath Town'.
  /// Null hides the word; the slot keeps its height so layout stays stable.
  final String? activeWaypoint;

  /// True pins the fill at 100% and blooms the destination node once per
  /// false→true flip. Mounting already-complete renders statically.
  final bool complete;

  /// Receipts mount with false — no car on a finished journey record.
  final bool showCarMarker;

  @override
  State<RouteStrip> createState() => _RouteStripState();
}

class _RouteStripState extends State<RouteStrip>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _bloom;
  late final AnimationController _fill;
  late final CurvedAnimation _bloomEased;
  late final CurvedAnimation _fillEased;
  late final Tween<double> _fillTween;
  late final Animation<double> _fillAnim;

  static const double _canvasHeight = 44;
  static const double _waypointSlotHeight = 20;

  double get _target =>
      widget.complete ? 1.0 : widget.progress.clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this);
    // Mount-complete guard: initState sees no false→true transition, so the
    // bloom controller stays dismissed and the painter renders the filled
    // destination node without replaying the ring.
    _bloom = AnimationController(vsync: this);
    _fill = AnimationController(vsync: this, value: 1);
    // Placeholder curves — didChangeDependencies swaps in the motion tokens
    // before the first frame paints.
    _bloomEased = CurvedAnimation(parent: _bloom, curve: Curves.linear);
    _fillEased = CurvedAnimation(parent: _fill, curve: Curves.linear);
    _fillTween = Tween<double>(begin: _target, end: _target);
    _fillAnim = _fillTween.animate(_fillEased);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.hoppin.motion;
    // The travelling charge pulse borrows the radar loop token: search and
    // track share one rhythm, and no new token is minted (the
    // no-inline-Duration rule holds).
    _pulse.duration = motion.radarPeriod;
    // Bloom = the choreographed 500ms celebration; slow carries 500ms.
    _bloom.duration = motion.slow;
    _bloomEased.curve = motion.easeOut;
    // Progress retarget: short ease-out so consumer jumps read continuous.
    _fill.duration = motion.quick;
    _fillEased.curve = motion.easeOut;
    _syncPulse();
  }

  @override
  void didUpdateWidget(RouteStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress ||
        oldWidget.complete != widget.complete) {
      _retarget();
    }
    if (!oldWidget.complete && widget.complete) {
      // Exactly once per false→true flip — same-value rebuilds never land
      // here, so the bloom cannot re-trigger.
      _bloom.forward(from: 0);
    } else if (oldWidget.complete && !widget.complete) {
      _bloom.stop();
      _bloom.value = 0;
    }
    if (oldWidget.complete != widget.complete) {
      _syncPulse();
    }
  }

  void _retarget() {
    _fillTween
      ..begin = _fillAnim.value
      ..end = _target;
    _fill.forward(from: 0);
  }

  void _syncPulse() {
    if (widget.complete) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _bloomEased.dispose();
    _fillEased.dispose();
    _pulse.dispose();
    _bloom.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final motion = hoppin.motion;
    final waypoint = widget.activeWaypoint;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Word waypoint — 1Hz-ish text kept OUTSIDE the per-frame canvas.
        SizedBox(
          height: _waypointSlotHeight,
          child: Center(
            child: AnimatedSwitcher(
              duration: motion.fade,
              switchInCurve: motion.easeOut,
              switchOutCurve: motion.easeOut,
              child: waypoint == null
                  ? const SizedBox.shrink(key: ValueKey('no-waypoint'))
                  : Text(
                      waypoint,
                      key: ValueKey<String>(waypoint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: hoppin.type.bodySmall.copyWith(
                        color: colors.textMid,
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(height: hoppin.spacing.xs),
        SizedBox(
          height: _canvasHeight,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: RouteStripPainter(
                progress: _fillAnim,
                pulse: _pulse,
                bloom: _bloomEased,
                complete: widget.complete,
                showCarMarker: widget.showCarMarker,
                accent: colors.accent,
                onAccent: colors.onAccent,
                pulseHighlight:
                    Color.lerp(colors.accent, colors.onAccent, 0.65)!,
                track: colors.hairline,
                pendingNode: colors.textMid,
              ),
            ),
          ),
        ),
        SizedBox(height: hoppin.spacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.originLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: hoppin.type.labelSmall.copyWith(color: colors.textMid),
              ),
            ),
            SizedBox(width: hoppin.spacing.md),
            Expanded(
              child: Text(
                widget.destinationLabel,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: hoppin.type.labelSmall.copyWith(color: colors.textHi),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Painter for [RouteStrip]. Public ONLY so tests can pin the token-driven
/// colours — not for direct use.
///
/// All motion enters through the listenable animations passed in (merged as
/// the `repaint:` listenable, so the canvas layer repaints without the tree
/// rebuilding); [shouldRepaint] reacts to configuration only.
class RouteStripPainter extends CustomPainter {
  RouteStripPainter({
    required this.progress,
    required this.pulse,
    required this.bloom,
    required this.complete,
    required this.showCarMarker,
    required this.accent,
    required this.onAccent,
    required this.pulseHighlight,
    required this.track,
    required this.pendingNode,
  }) : super(repaint: Listenable.merge([progress, pulse, bloom]));

  /// Eased display progress 0..1 — the fill retarget animation.
  final Animation<double> progress;

  /// Repeating 0..1 phase of the travelling charge pulse.
  final Animation<double> pulse;

  /// Eased 0..1 bloom; dismissed-and-zero means "never bloomed".
  final Animation<double> bloom;

  /// Pins the fill at 100% and fills the destination node.
  final bool complete;

  /// Draws the car glyph at the progress fraction.
  final bool showCarMarker;

  /// Fill, nodes and car body — the lane accent token.
  final Color accent;

  /// Car chevron glyph — the on-accent token.
  final Color onAccent;

  /// Brightest point of the charge pulse (accent lerped toward on-accent).
  final Color pulseHighlight;

  /// Full-width hairline track token.
  final Color track;

  /// Outline of the not-yet-reached destination node.
  final Color pendingNode;

  static const double _stroke = 3;
  static const double _nodeRadius = 5;
  static const double _bloomMaxRadius = 17;
  static const double _carRadius = 9;
  static const double _edgeInset = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    const startX = _edgeInset;
    final endX = size.width - _edgeInset;
    if (endX <= startX) {
      return;
    }
    final span = endX - startX;
    final p = progress.value.clamp(0.0, 1.0);
    final fillEndX = startX + span * p;

    // Hairline full-width track.
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawLine(
      Offset(startX, centerY),
      Offset(endX, centerY),
      trackPaint,
    );

    // Accent fill up to the display progress.
    if (p > 0) {
      final fillPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = accent;
      canvas.drawLine(
        Offset(startX, centerY),
        Offset(fillEndX, centerY),
        fillPaint,
      );
    }

    // Travelling charge pulse — a brighter gradient segment sweeping the
    // FILLED length only. Plain gradient shader on the stroke paint: no
    // saveLayer, no blur. Rests once complete (calm after arrival).
    if (!complete && p > 0.02) {
      final filled = span * p;
      final segHalf = (filled * 0.16).clamp(8.0, 28.0);
      final segCenter = startX + filled * pulse.value;
      final segStart = (segCenter - segHalf).clamp(startX, fillEndX);
      final segEnd = (segCenter + segHalf).clamp(startX, fillEndX);
      if (segEnd - segStart > 1) {
        final segRect = Rect.fromLTRB(
          segStart,
          centerY - _stroke,
          segEnd,
          centerY + _stroke,
        );
        final pulsePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              pulseHighlight.withValues(alpha: 0),
              pulseHighlight.withValues(alpha: 0.9),
              pulseHighlight.withValues(alpha: 0),
            ],
          ).createShader(segRect);
        canvas.drawLine(
          Offset(segStart, centerY),
          Offset(segEnd, centerY),
          pulsePaint,
        );
      }
    }

    // Origin node — the filled "you started here" dot.
    canvas.drawCircle(
      Offset(startX, centerY),
      _nodeRadius,
      Paint()..color = accent,
    );

    // Destination node — outlined until complete. Bloom = expanding ring +
    // fill-in; both alphas ride the paint colour. A strip mounted
    // already-complete arrives with the bloom dismissed, so it renders the
    // filled node with no ring.
    final destCenter = Offset(endX, centerY);
    final bloomRunning = bloom.status == AnimationStatus.forward;
    final bloomT = bloom.value;
    final destFillAlpha = complete ? (bloomRunning ? bloomT : 1.0) : 0.0;

    if (destFillAlpha < 1) {
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = pendingNode;
      canvas.drawCircle(destCenter, _nodeRadius, outline);
    }
    if (destFillAlpha > 0) {
      canvas.drawCircle(
        destCenter,
        _nodeRadius,
        Paint()..color = accent.withValues(alpha: destFillAlpha),
      );
    }
    if (bloomRunning && bloomT > 0) {
      final ringRadius =
          _nodeRadius + (_bloomMaxRadius - _nodeRadius) * bloomT;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: (1 - bloomT) * 0.6);
      canvas.drawCircle(destCenter, ringRadius, ringPaint);
    }

    // Car marker at the progress fraction — fades out through the bloom
    // (arrival: the car "becomes" the destination node).
    if (showCarMarker) {
      final carAlpha = complete ? (bloomRunning ? 1 - bloomT : 0.0) : 1.0;
      if (carAlpha > 0.01) {
        final carCenter = Offset(fillEndX, centerY);
        canvas.drawCircle(
          carCenter,
          _carRadius,
          Paint()..color = accent.withValues(alpha: carAlpha),
        );
        final chevron = Path()
          ..moveTo(carCenter.dx - 2, carCenter.dy - 3.5)
          ..lineTo(carCenter.dx + 2.5, carCenter.dy)
          ..lineTo(carCenter.dx - 2, carCenter.dy + 3.5);
        final chevronPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = onAccent.withValues(alpha: carAlpha);
        canvas.drawPath(chevron, chevronPaint);
      }
    }
  }

  @override
  bool shouldRepaint(RouteStripPainter oldDelegate) {
    return oldDelegate.complete != complete ||
        oldDelegate.showCarMarker != showCarMarker ||
        oldDelegate.accent != accent ||
        oldDelegate.onAccent != onAccent ||
        oldDelegate.pulseHighlight != pulseHighlight ||
        oldDelegate.track != track ||
        oldDelegate.pendingNode != pendingNode;
  }
}
