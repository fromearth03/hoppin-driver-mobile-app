import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

/// The matching-state radar — phase-offset rings expanding from a stylised
/// "you are here" origin dot, driven by ONE repeating controller on ONE
/// canvas layer (flutter-web-feasibility §3).
///
/// Pure presentation with no inputs beyond geometry: the staged matching
/// copy, the cancel affordance, and the match timing all live in the
/// consuming riblet — the radar just breathes under them.
///
/// Web budget: each ring's fade rides its stroke paint's colour alpha
/// (never a widget-level fade), no blur, no per-frame shadows; the painter
/// repaints via its `repaint:` listenable without rebuilding the tree, and
/// the whole canvas sits inside a [RepaintBoundary].
class RadarPulse extends StatefulWidget {
  const RadarPulse({this.size = 160.0, this.rings = 3, super.key});

  /// Square edge length of the radar canvas.
  final double size;

  /// Number of concentric expanding rings (3–4 reads best).
  final int rings;

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _phase = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // One ring expansion period — the radar loop token.
    _phase.duration = context.hoppin.motion.radarPeriod;
    if (!_running) {
      _running = true;
      _phase.repeat();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hoppin.colors;
    return Semantics(
      label: 'Searching nearby',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: RadarPulsePainter(
              rings: widget.rings,
              accent: colors.accent,
              phase: _phase,
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter for [RadarPulse]. Public ONLY so tests can pin the token-driven
/// accent — not for direct use.
///
/// Per-ring phase `(t + i / rings) % 1.0` maps one repeating controller to
/// staggered expanding circles. §5 spec: each ring is born at base radius
/// and eases OUT to ~2.5× (the "scale 1.0→~2.5" cell), while its paint
/// alpha fades 0.35→0 — always ON THE PAINT COLOUR, never a widget fade.
/// The controller arrives as the `repaint:` listenable, so frames repaint
/// this canvas layer only — the tree never rebuilds.
class RadarPulsePainter extends CustomPainter {
  RadarPulsePainter({
    required this.rings,
    required this.accent,
    required this.phase,
  }) : super(repaint: phase);

  /// Number of concentric rings.
  final int rings;

  /// Ring stroke, origin dot, and glow — the lane accent token.
  final Color accent;

  /// Repeating 0..1 loop phase.
  final Animation<double> phase;

  static const double _ringStroke = 2;
  static const double _dotRadius = 5;

  /// §5: rings expand from 1.0× to ~2.5× of their birth radius.
  static const double _scaleSpan = 2.5;

  /// §5: ring paint-alpha starts at 0.35 and fades to 0.
  static const double _maxRingAlpha = 0.35;
  static const double _glowAlpha = 0.08;

  /// §5: ease-out expansion — fast birth, drifting arrival. Hypnotic, not
  /// frantic.
  static const Curve _expansion = Curves.easeOut;

  // Static inner glow — the gradient never animates, so the shader is
  // built once per canvas size and reused across frames.
  Shader? _glowShader;
  Size? _glowSize;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2 - _ringStroke;
    if (maxRadius <= 0) {
      return;
    }

    if (_glowSize != size) {
      _glowSize = size;
      _glowShader = RadialGradient(
        colors: [
          accent.withValues(alpha: _glowAlpha),
          accent.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    }
    canvas.drawCircle(center, maxRadius, Paint()..shader = _glowShader);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringStroke;
    final baseRadius = maxRadius / _scaleSpan;
    final t0 = phase.value;
    for (var i = 0; i < rings; i++) {
      final t = (t0 + i / rings) % 1.0;
      // Radius rides the eased phase (1.0×→2.5× of the birth radius);
      // alpha fades linearly so the drift-out reads calm.
      final radius =
          baseRadius + _expansion.transform(t) * (maxRadius - baseRadius);
      if (radius <= _dotRadius) {
        // Degenerate canvases only: rings never paint under the dot.
        continue;
      }
      ringPaint.color = accent.withValues(alpha: (1 - t) * _maxRingAlpha);
      canvas.drawCircle(center, radius, ringPaint);
    }

    // The stylised "you are here" origin dot.
    canvas.drawCircle(center, _dotRadius, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(RadarPulsePainter oldDelegate) {
    return oldDelegate.rings != rings || oldDelegate.accent != accent;
  }
}
