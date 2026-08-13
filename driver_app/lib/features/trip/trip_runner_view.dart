import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../dashboard/widgets/seam_unavailable_states.dart';
import 'map/map_builder.dart';
import 'map/map_view.dart';
import 'stuck/stuck_exit_sheet.dart';
import 'trip_runner_builder.dart';
import 'trip_runner_state.dart';
import 'widgets/trip_comms_row.dart';
import 'widgets/waiting_elapsed.dart';
import 'widgets/waiting_policy_unavailable.dart';

/// Dumb render layer of the trip runner riblet (DOCS/05): state in via
/// `ref.watch(tripRunnerInteractorProvider(rideId))`, intents out via
/// `.notifier`. No repositories, no navigation, no timers, no demo
/// branches.
///
/// Layout (dark-first, "one place to look"): the full-bleed nav map canvas
/// (MAP-04 — heading marker, objective route, chase camera; hidden in live
/// mode where the geo seams answer null) BEHIND a large ambient status
/// headline over THE persistent bottom card — one fixed-height HopCard
/// under one const key that MORPHS through the trip and never unmounts.
/// One primary action per phase: tap Arrived (low stakes), slide to start,
/// slide to complete (money-affecting transitions are gesture-gated).
class TripRunnerView extends ConsumerWidget {
  const TripRunnerView({required this.rideId, super.key});

  /// The ride this runner renders.
  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tripRunnerInteractorProvider(rideId));
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The nav canvas sits behind everything; the empty headline zone
          // passes pan/zoom straight through to the map.
          Positioned.fill(child: DriverTripMap(rideId: rideId)),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                hoppin.spacing.gutter,
                hoppin.spacing.sm,
                hoppin.spacing.gutter,
                hoppin.spacing.gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The headline zone is empty space over the map, so it is the
                  // FIRST thing that gives on a short viewport: Expanded lets
                  // it collapse toward nothing before the card below is asked
                  // to yield anything.
                  Expanded(child: _AmbientHeadline(state: state)),
                  if (state.error != null) ...[
                    HopBanner.error(message: state.error!),
                    SizedBox(height: hoppin.spacing.md),
                  ],
                  Listener(
                    behavior: HitTestBehavior.opaque,
                    child: _RunnerCard(state: state, rideId: rideId),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The shared card-morph rhythm (driver-ux-motion §5): incoming content
/// fades in while sliding up 8px; the outgoing content plays the same
/// transition reversed (fade + slide-down 8px).
Widget _morphTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
    opacity: animation,
    child: AnimatedBuilder(
      animation: animation,
      builder: (context, inner) => Transform.translate(
        offset: Offset(0, 8 * (1 - animation.value)),
        child: inner,
      ),
      child: child,
    ),
  );
}

/// The §5 morph choreography on one AnimatedSwitcher: the outgoing content
/// exits over morphOut (120ms, ease-in), the incoming content rises over
/// morphIn (200ms, ease-out) STARTING morphOut − morphOverlap into the
/// switch — so the two overlap by ~40ms instead of cross-fading fully.
/// Implemented as an Interval head on the incoming window (total = out +
/// in − overlap); every duration is a HoppinMotion token.
Widget _morphSwitcher({required HoppinMotion motion, required Widget child}) {
  final total = motion.morphOut + motion.morphIn - motion.morphOverlap;
  final inStart = motion.morphOut - motion.morphOverlap;
  return AnimatedSwitcher(
    duration: total,
    reverseDuration: motion.morphOut,
    switchInCurve: Interval(
      inStart.inMicroseconds / total.inMicroseconds,
      1,
      curve: motion.easeOut,
    ),
    switchOutCurve: Curves.easeIn,
    transitionBuilder: _morphTransition,
    child: child,
  );
}

/// The big ambient status line — one headline per phase, rewriting inside
/// the same AnimatedSwitcher rhythm as the card's action zone.
class _AmbientHeadline extends StatelessWidget {
  const _AmbientHeadline({required this.state});

  final TripRunnerState state;

  String get _headline {
    final rider = state.riderContext;
    return switch (state.phase) {
      TripPhase.headingToPickup =>
        rider?.pickupLabel != null
            ? 'Head to ${rider!.pickupLabel}'
            : 'Head to pickup',
      TripPhase.arrivedAtPickup =>
        rider == null
            ? 'Waiting for your rider'
            : 'Waiting for ${rider.name.split(' ').first}',
      TripPhase.inTrip => 'Trip in progress',
      TripPhase.completed => 'Trip complete',
    };
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    // Top-align the phase headline instead of centering it. When the nav map
    // is unavailable (live gaps #17/#41) its designed rung fills the canvas
    // behind this layer with its OWN centered "No map for this trip" copy; a
    // centered headline here lands on top of that text and the two overlap.
    // Pinning the headline to the top keeps it clear of the rung and reads as
    // a status bar over the map either way.
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: hoppin.spacing.sm),
        child: _morphSwitcher(
          motion: hoppin.motion,
          child: Text(
            _headline,
            key: ValueKey(state.phase),
            textAlign: TextAlign.center,
            style: hoppin.type.headline.copyWith(color: hoppin.colors.textHi),
          ),
        ),
      ),
    );
  }
}

/// THE persistent bottom card: rider context row, stage spine, and the
/// morphing action zone. Every section is fixed-height (no layout thrash)
/// and the card carries one const key — it NEVER unmounts between phases;
/// only its action zone morphs.
class _RunnerCard extends ConsumerWidget {
  const _RunnerCard({required this.state, required this.rideId});

  final TripRunnerState state;
  final String rideId;

  static const double _actionZoneHeight = 80;

  int get _activeStage => switch (state.phase) {
    TripPhase.headingToPickup || TripPhase.arrivedAtPickup => 0,
    TripPhase.inTrip => 1,
    TripPhase.completed => 2,
  };

  /// The ETA rung: seconds-to-pickup from telemetry, floored at the calm
  /// 'Arriving now' hold. Empty when telemetry has nothing to say.
  String get _etaLine {
    final eta = state.etaSeconds;
    if (eta == null) return '';
    if (eta <= 0) return 'Arriving now';
    return '${eta ~/ 60}:${(eta % 60).toString().padLeft(2, '0')} to pickup';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;

    // 🔴 GLASS AT THE `sheet` TIER — the map is the thing it is frosting.
    //
    // This card floats over the FULL-BLEED nav canvas, so the blur has real
    // content to sample: the one condition under which this material means
    // anything (an unlayered HopGlass degrades silently into a tinted box that
    // photographs perfectly — see the primitive's own note).
    //
    // The tier is a DUTY, not a taste call. This card carries body copy the
    // driver READS mid-job — the rider row, the stage spine, the ETA line — so
    // it takes `sheet` (86%), whose alpha is pinned by a measured worst-case
    // contrast. The chrome tier's 72% puts dark textMid at 3.94:1, under the AA
    // floor, and a driver squinting at a route through a pretty pane is a
    // safety problem, not a style one.
    //
    // HopGlass brings its own RepaintBoundary around the backdrop pass (the
    // geometry never changes, and without it anything repainting nearby drags
    // the blur through a re-rasterise it did not need).
    return HopGlass(
      key: const ValueKey('trip-runner-card'),
      borderRadius: BorderRadius.circular(hoppin.radii.card),
      tier: HopGlassTier.sheet,
      child: Padding(
        padding: EdgeInsets.all(hoppin.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The rider slot: live rider-context (other-party rating + comments).
            if (state.riderContext != null)
              _RiderRow(rider: state.riderContext)
            else
              const RiderContextUnavailable(),
            SizedBox(height: hoppin.spacing.lg),
            TripStageSpine(activeIndex: _activeStage),
            SizedBox(height: hoppin.spacing.lg),
            // The waiting surface — only at the pickup, once the driver has
            // stamped Arrived. The clock COUNTS UP (no countdown, no money) and
            // the #44 policy rung sits beside it, disclosing that there is no
            // waiting charge and routing a stranded driver to the stuck exit.
            //
            if (state.phase == TripPhase.arrivedAtPickup &&
                state.arrivedAt != null) ...[
              WaitingElapsed(since: state.arrivedAt!),
              SizedBox(height: hoppin.spacing.md),
              WaitingPolicyUnavailable(
                onOpenStuck: () => showStuckExitSheet(context, rideId: rideId),
              ),
              SizedBox(height: hoppin.spacing.lg),
            ],
            SizedBox(
              height: _actionZoneHeight,
              child: _morphSwitcher(
                motion: hoppin.motion,
                child: _actionZone(context, ref),
              ),
            ),
            // The comms row — Chat, Call, I'm stuck — on every phase the driver
            // is actively working a rider (heading / arrived / in-trip). It is
            // GONE on `completed`, where the job is over and the exit is Done.
            //
            // 🔴 ONE TAP EACH, AND THEY STAY LIVE IN MOTION. Not wrapped in the
            // typing lock — a cradled tap is legal and it is how the job gets
            // done. This is exactly what 15-00's gate side B protects.
            if (state.phase != TripPhase.completed) ...[
              SizedBox(height: hoppin.spacing.md),
              TripCommsRow(rideId: rideId),
            ],
          ],
        ),
      ),
    );
  }

  /// One primary action per phase: tap → slide → slide → quiet close.
  Widget _actionZone(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final notifier = ref.read(tripRunnerInteractorProvider(rideId).notifier);

    return switch (state.phase) {
      TripPhase.headingToPickup => Column(
        key: const ValueKey('action-heading'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The Figma's trio, minus the third the backend cannot supply.
          // It reuses the ETA line's EXISTING 20px box rather than adding a
          // row: this card is fixed-height by design (no layout thrash), and
          // a new rung overflowed it by 16px on the demo path — the one path
          // where the geometry actually resolves.
          SizedBox(
            height: 20,
            child: _ProgressLine(etaLine: _etaLine, rideId: rideId),
          ),
          SizedBox(height: hoppin.spacing.sm),
          HopButton.primary(
            label: 'Arrived',
            busy: state.busy,
            onPressed: () => notifier.arrived(),
          ),
        ],
      ),
      TripPhase.arrivedAtPickup => Center(
        key: const ValueKey('action-start'),
        child: SlideToConfirm(
          key: const ValueKey('slide-start'),
          label: 'Slide to start trip',
          enabled: !state.busy,
          onConfirmed: () => notifier.startTrip(),
        ),
      ),
      TripPhase.inTrip => Center(
        key: const ValueKey('action-complete'),
        child: SlideToConfirm(
          key: const ValueKey('slide-complete'),
          label: 'Slide to complete',
          enabled: !state.busy,
          fillColor: colors.success,
          onConfirmed: () => notifier.complete(),
        ),
      ),
      // 🔴 THE EXIT. This used to be static text — no button, no navigation,
      // no control of any kind — and the driver's ONLY way off this card was
      // the earned-moment sheet, which was gated on a money figure the live
      // backend never sends. Every completed trip on live ended with the
      // driver looking at the words "Trip complete" and nothing to press.
      //
      // The Done affordance below depends on NOTHING: no seam, no repository,
      // no payout. It is here whether or not a figure ever arrives.
      TripPhase.completed => Center(
        key: const ValueKey('action-done'),
        child: HopButton.primary(
          label: 'Done',
          onPressed: () => notifier.dismiss(),
        ),
      ),
    };
  }
}

/// 🔴 THE DISTANCE RUNG — GEOMETRY OR NOTHING.
///
/// The Figma draws a Distance/ETA/Fare trio at the top of the trip card. Two of
/// the three are buildable honestly today; the third is not, and the difference
/// is the entire reason this widget is shaped the way it is.
///
/// DISTANCE IS REAL. The map interactor sums it along the current leg from the
/// car's own position (haversine, 1 Hz), and it is ALREADY gated there on
/// `legEndsAtObjective` — a leg that does not END at the objective yields null
/// rather than a number that merely looks right. This widget renders exactly
/// what that computation answered and never substitutes for it. It reads the
/// SIBLING map brain rather than recomputing: two distance sums drift apart,
/// and the driver would have no way to know which one lied.
///
/// It renders NOTHING when `remainingMeters` is null. On live that is every
/// trip — both geo seams (#41 driverPosition, #17 rideGeo) answer null on every
/// request, the map sits at MapPhase.hidden, and so this line is simply absent.
/// That is the designed outcome, not a gap: no distance is better than an
/// invented one, and a driver told they are 2 miles from a rider they are
/// nowhere near would believe it.
///
/// FARE IS ABSENT, AND NOT BY OVERSIGHT. `TripRunnerState` carries no fare
/// field, the runner is keyed only by rideId, and the `Ride` it receives
/// carries `fare_id` — an opaque string with NO resolver anywhere in the
/// codebase. There is no figure to render, so rendering one would fabricate a
/// self-employed person's pay. It is a backend ask, not a layout problem.
class _ProgressLine extends ConsumerWidget {
  const _ProgressLine({required this.etaLine, required this.rideId});

  /// The already-formatted ETA rung from the runner state ('' when
  /// telemetry has nothing to say).
  final String etaLine;

  /// The ride whose map brain supplies the along-leg figure.
  final String rideId;

  /// Metres per mile — the same constant the map's own objective chip
  /// converts with, so the card and the chip can never disagree by a
  /// rounding rule.
  static const double _metersPerMile = 1609.344;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(tripMapInteractorProvider(rideId));
    final meters = map.remainingMeters;
    final hoppin = context.hoppin;

    // Distance first (it is the spatial fact), ETA second — joined only when
    // both exist. Either one alone renders alone; neither renders an empty box
    // that still holds its 20px, so the card's height never moves.
    final distance = meters == null
        ? null
        : '${(meters / _metersPerMile).toStringAsFixed(1)} mi to '
              // The objective word flips WITH the pin and the track, in the
              // map's own emission — never assumed here.
              '${map.objectiveLabel.toLowerCase()}';

    // Calm by design — 'Arriving now' carries no urgency styling; tabular
    // figures keep both the distance and the ETA steady as they tick.
    final style = hoppin.type.numeralCaption.copyWith(
      color: hoppin.colors.textMid,
    );

    // 🔴 TWO Text WIDGETS, NOT ONE JOINED STRING. Distance and ETA are
    // independent facts from different brains (map geometry vs. runner
    // telemetry) and each must stay independently addressable — a joined
    // string makes 'Arriving now' unfindable the moment a distance appears
    // beside it, which silently broke the router suite's exact-match
    // assertion on the demo path. Separate widgets keep every existing
    // guarantee about the ETA true whether or not geometry exists.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (distance != null)
          Flexible(
            child: Text(
              distance,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        if (distance != null && etaLine.isNotEmpty) ...[
          SizedBox(width: hoppin.spacing.sm),
          Text('·', style: style),
          SizedBox(width: hoppin.spacing.sm),
        ],
        if (etaLine.isNotEmpty)
          Flexible(
            child: Text(
              etaLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
      ],
    );
  }
}

/// Who is being picked up: initials, name, pickup label, the rider's rating
/// (never the driver's own) and the latest comment about them.
class _RiderRow extends StatelessWidget {
  const _RiderRow({required this.rider}) : assert(rider != null);

  final TripRiderContext? rider;

  String _initials(String name) {
    final parts = name.split(' ').where((p) => p.isNotEmpty).take(2);
    return parts.map((p) => p[0].toUpperCase()).join();
  }

  String? _ratingPill(TripRiderContext r) {
    if (r.rating == null || r.ratingCount <= 0) return null;
    if (r.ratingCount > 1) {
      return '★ ${r.rating!.toStringAsFixed(1)} (${r.ratingCount})';
    }
    return '★ ${r.rating!.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final r = rider!;
    final comment =
        r.recentComments.isNotEmpty ? r.recentComments.first : null;
    final pill = _ratingPill(r);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.accentSubtle,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initials(r.name),
                style: hoppin.type.label.copyWith(color: colors.accent),
              ),
            ),
          ),
        ),
        SizedBox(width: hoppin.spacing.md),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: hoppin.type.titleSmall.copyWith(color: colors.textHi),
              ),
              if (r.pickupLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  r.pickupLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: hoppin.type.labelSmall.copyWith(color: colors.textMid),
                ),
              ],
              if (comment != null) ...[
                const SizedBox(height: 2),
                Text(
                  '"$comment"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: hoppin.type.labelSmall.copyWith(color: colors.textMid),
                ),
              ],
            ],
          ),
        ),
        if (pill != null) ...[
          SizedBox(width: hoppin.spacing.sm),
          StatusPill(label: pill),
        ],
      ],
    );
  }
}

/// The stage-progress spine: three labelled dots — 'Pickup', 'On board',
/// 'Complete' — joined by hairlines. [activeIndex] is the stage currently
/// underway: earlier dots and legs render complete in the accent role, and
/// a dot pops (1→1.3→1 over dotPop, ~300ms) the moment it fills.
class TripStageSpine extends StatefulWidget {
  const TripStageSpine({required this.activeIndex, super.key});

  /// 0 = Pickup, 1 = On board, 2 = Complete.
  final int activeIndex;

  /// The locked spine copy.
  static const labels = ['Pickup', 'On board', 'Complete'];

  @override
  State<TripStageSpine> createState() => _TripStageSpineState();
}

class _TripStageSpineState extends State<TripStageSpine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;
  late final Animation<double> _scale;
  int _poppingIndex = -1;

  @override
  void initState() {
    super.initState();
    // Duration-less in initState; the token resolves in
    // didChangeDependencies (05-02 controller convention).
    _pop = AnimationController(vsync: this, value: 1);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 1,
      ),
    ]).animate(_pop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pop.duration = context.hoppin.motion.dotPop;
  }

  @override
  void didUpdateWidget(TripStageSpine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndex > oldWidget.activeIndex) {
      _poppingIndex = widget.activeIndex;
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
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < TripStageSpine.labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5, left: 6, right: 6),
                child: Container(
                  height: 1,
                  color: i <= widget.activeIndex
                      ? colors.accent
                      : colors.hairline,
                ),
              ),
            ),
          // The stage labels are intrinsic-width text. Unconstrained they sum
          // past the card's inner width on a 320-360pt phone (a 7.5px overflow
          // on EVERY phase, because the spine is always mounted) and the
          // connecting hairlines have no room left to claim. Flexible lets the
          // labels give way before the row does; the hairlines keep their
          // Expanded share.
          Flexible(
            child: _Stage(
              label: TripStageSpine.labels[i],
              reached: i <= widget.activeIndex,
              scale: i == _poppingIndex ? _scale : null,
            ),
          ),
        ],
      ],
    );
  }
}

/// One dot + label pair. [scale] is non-null only while this dot plays its
/// fill pop; the transform never touches layout.
class _Stage extends StatelessWidget {
  const _Stage({required this.label, required this.reached, this.scale});

  final String label;
  final bool reached;
  final Animation<double>? scale;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    final dot = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached ? colors.accent : Colors.transparent,
        border: reached ? null : Border.all(color: colors.hairline),
      ),
      child: const SizedBox(width: 11, height: 11),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (scale == null)
          dot
        else
          AnimatedBuilder(
            animation: scale!,
            builder: (context, child) =>
                Transform.scale(scale: scale!.value, child: child),
            child: dot,
          ),
        SizedBox(height: hoppin.spacing.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: hoppin.type.labelSmall.copyWith(
            color: reached ? colors.textHi : colors.textMid,
          ),
        ),
      ],
    );
  }
}
