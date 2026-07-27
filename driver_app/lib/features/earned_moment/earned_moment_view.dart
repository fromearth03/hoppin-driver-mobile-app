import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../trip/trip_runner_builder.dart';
import 'earned_moment_builder.dart';
import 'earned_moment_state.dart';

/// Dumb render layer of the earned-moment sheet (DOCS/05): the check pop,
/// the 'You earned' caption, and the £0.00 → £x.xx odometer. Transform and
/// paint-alpha only — no Opacity widgets, no layout animation. A tap
/// anywhere skips to done (the router collapses on done).
///
/// 🔴 THE FIGURE IS OPTIONAL. THE CONFIRMATION IS NOT.
///
/// The payout is WATCHED off the trip runner rather than passed in at attach,
/// because it is DECORATION: it may arrive a beat late (demo), or never at all
/// (live — it derives from the #7 telemetry seam the backend does not serve).
/// The sheet opens the moment the trip completes either way, and it always
/// collapses back to the dashboard, because this sheet is the trip's exit and
/// an exit may not hang on a money figure.
///
/// With no figure it says so PLAINLY. It never substitutes £0.00: a zero
/// rendered where a real payout belongs tells a driver they earned nothing,
/// which is not what we know — we know nothing (D2).
class EarnedMomentView extends ConsumerWidget {
  const EarnedMomentView({required this.rideId, super.key});

  /// The completed ride this moment closes out.
  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(earnedMomentInteractorProvider(rideId));
    final hoppin = context.hoppin;
    // Decoration, watched live: null until (and unless) the server sends it.
    final pence = ref.watch(
      tripRunnerInteractorProvider(rideId).select((s) => s.payoutPence),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          ref.read(earnedMomentInteractorProvider(rideId).notifier).skip(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: hoppin.spacing.sm),
          const EarnedCheck(),
          SizedBox(height: hoppin.spacing.lg),
          if (pence != null) ...[
            Text(
              'You earned',
              style: hoppin.type.bodySmall.copyWith(
                color: hoppin.colors.textMid,
              ),
            ),
            SizedBox(height: hoppin.spacing.xs),
            // The 0 → payout rebuild IS the count-up trigger: the ticker
            // mounts at £0.00 during the check pop and retargets to the
            // payout the moment the countUp phase lands.
            MoneyTicker(
              pence: state.phase == EarnedPhase.checkPop ? 0 : pence,
              duration: hoppin.motion.tickerCountUp,
              // The hero numeral: moneyHero merges over the ticker's tabular
              // GeistMono default, so digits never jitter.
              style: hoppin.type.moneyHero,
            ),
          ] else
            const EarnedFigureUnavailable(),
          SizedBox(height: hoppin.spacing.md),
        ],
      ),
    );
  }
}

/// The no-figure rung of the earned moment (seam #7).
///
/// The trip DID complete — the server took it, and the fare is on the server's
/// side of the wire. What we cannot do is tell the driver the number, because
/// there is no driver-telemetry read to ask (`todayStats()` answers null on
/// every live request). So the sheet celebrates the thing that is TRUE (the
/// trip is done) and is plain about the thing that is not available (the
/// figure), and it never invents one.
class EarnedFigureUnavailable extends StatelessWidget {
  /// Creates the #7 no-payout-figure rung.
  const EarnedFigureUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Trip complete',
          textAlign: TextAlign.center,
          style: hoppin.type.title.copyWith(color: hoppin.colors.textHi),
        ),
        SizedBox(height: hoppin.spacing.xs),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hoppin.spacing.lg),
          child: Text(
            "Your fare is recorded. We can't show today's earnings figure yet "
            '— trip telemetry is not switched on.',
            textAlign: TextAlign.center,
            style:
                hoppin.type.bodySmall.copyWith(color: hoppin.colors.textMid),
          ),
        ),
      ],
    );
  }
}

/// The success check: a subtle disc with the tick stroke DRAWING itself
/// via an animated PathMetric extract (~300ms) while the whole paint
/// scales 0→1.1→1.0 (overshoot, ~400ms). Painted inside its own
/// RepaintBoundary; transform only, never layout.
class EarnedCheck extends StatefulWidget {
  const EarnedCheck({super.key});

  @override
  State<EarnedCheck> createState() => _EarnedCheckState();
}

class _EarnedCheckState extends State<EarnedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;
  late final Animation<double> _scale;
  late final Animation<double> _stroke;
  bool _kicked = false;

  @override
  void initState() {
    super.initState();
    // Duration-less in initState; the token resolves in
    // didChangeDependencies (05-02 controller convention).
    _pop = AnimationController(vsync: this);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 3,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]).animate(_pop);
    // The stroke finishes inside the pop: ~300ms of the 400ms beat.
    _stroke = CurvedAnimation(
      parent: _pop,
      curve: const Interval(0, 0.75, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pop.duration = context.hoppin.motion.checkPop;
    if (!_kicked) {
      _kicked = true;
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hoppin.colors;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pop,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: CustomPaint(
          size: const Size(72, 72),
          painter: _CheckPainter(
            strokeT: _stroke.value,
            discColor: colors.successSubtle,
            tickColor: colors.success,
          ),
        ),
      ),
    );
  }
}

/// Disc + tick painter. [strokeT] 0..1 extracts the drawn portion of the
/// tick path (PathMetric), so the check literally draws itself in.
class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.strokeT,
    required this.discColor,
    required this.tickColor,
  });

  final double strokeT;
  final Color discColor;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width / 2, Paint()..color = discColor);

    if (strokeT <= 0) return;
    final tick = Path()
      ..moveTo(size.width * 0.30, size.height * 0.53)
      ..lineTo(size.width * 0.44, size.height * 0.66)
      ..lineTo(size.width * 0.70, size.height * 0.37);
    final paint = Paint()
      ..color = tickColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in tick.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * strokeT), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.strokeT != strokeT ||
      oldDelegate.discColor != discColor ||
      oldDelegate.tickColor != tickColor;
}
