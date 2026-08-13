import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../providers.dart';
import '../dashboard/widgets/seam_unavailable_states.dart';
import '../trip/map/map_builder.dart';
import 'offer_takeover_builder.dart';
import 'offer_takeover_state.dart';
import 'widgets/offer_reassigned_state.dart';

/// Dumb render layer of the offer takeover riblet (DOCS/05): state in via
/// `ref.watch(offerTakeoverInteractorProvider(offer))`, intents out via
/// `.notifier`. No repositories, no navigation, no demo branches. The
/// scrim + slide-up entrance is the ROUTE transition's (see the router);
/// this surface renders the card and its in-card choreography.
///
/// The locked payout-first anatomy (03-CONTEXT — the money is the message):
/// ghost Decline top-corner → hero £ (THE largest text on screen) →
/// context line → rider row → giant Accept inside the CountdownRing with
/// numeric seconds ALWAYS visible → tap-anywhere-on-card accepts.
class OfferTakeoverView extends ConsumerWidget {
  const OfferTakeoverView({required this.offer, super.key});

  /// The offer this takeover presents — also the interactor's family key.
  final RideOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offerTakeoverInteractorProvider(offer));
    // Seam #6. `.value` is null BOTH while the one-shot is in flight and when
    // it resolves to the live null — the rung must only answer the second. A
    // loading frame reserves the slot quietly instead of flashing the rung and
    // re-laying the locked anatomy out from under itself.
    final riderAsync = ref.watch(tripRiderContextProvider(offer.rideId));
    final riderContext = riderAsync.value;
    final riderSeamed = !riderAsync.isLoading && riderContext == null;
    final hoppin = context.hoppin;
    final motion = hoppin.motion;

    // The card slides away for every terminal exit — the quiet expired note,
    // the reassigned apology, the compliance redirect, and the dismiss pop.
    final slidAway = state.phase == OfferPhase.expired ||
        state.phase == OfferPhase.reassigned ||
        state.phase == OfferPhase.notEligible ||
        state.phase == OfferPhase.dismissed;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The quiet expired note — neutral tones, NEVER red; it floats
          // where the card was while the note beat plays out.
          Align(
            alignment: const Alignment(0, 0.55),
            child: AnimatedOpacity(
              opacity: state.phase == OfferPhase.expired ? 1 : 0,
              duration: motion.fade,
              child: const StatusPill(label: 'Offer expired'),
            ),
          ),
          // 🔴 409 OFFER_EXPIRED → the non-blaming reassigned state. Not red,
          // not "error", not "failed" — an apology in neutral tones that holds
          // for the beat, then the router pops the driver back to the dashboard.
          if (state.phase == OfferPhase.reassigned)
            const Positioned.fill(child: OfferReassignedState()),
          // 🔴 403 NOT_ELIGIBLE → one brief, HONEST line, then the router routes
          // to the compliance wallet. 🔴 THE LINE NAMES NO CAUSE. NOT_ELIGIBLE
          // is compliance OR restriction OR suspension and we do not know which
          // (#30) — so the copy says only that we cannot see why, and hands off
          // to the place they can act. Any guessed cause here is a defect:
          // telling a suspended driver their paperwork lapsed is a lie about
          // their own status.
          if (state.phase == OfferPhase.notEligible)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hoppin.spacing.gutter),
                child: Text(
                  "You can't accept rides right now. We can't see why from "
                  'here — taking you to where you can check.',
                  textAlign: TextAlign.center,
                  style: hoppin.type.title.copyWith(color: hoppin.colors.textMid),
                ),
              ),
            ),
          // The takeover card: bottom-anchored; expiry slides it down
          // (the reverse of its entrance) revealing the note above.
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              offset: slidAway ? const Offset(0, 1.1) : Offset.zero,
              duration: motion.quick,
              curve: Curves.easeIn,
              child: _TakeoverCard(
                offer: offer,
                state: state,
                riderContext: riderContext,
                riderSeamed: riderSeamed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// THE card. Stateful only for the payout entrance stagger (§5 'Offer
/// entrance': the eye ends on the money — fade + 12px rise, delayed so it
/// lands as the card settles).
class _TakeoverCard extends ConsumerStatefulWidget {
  const _TakeoverCard({
    required this.offer,
    required this.state,
    required this.riderContext,
    required this.riderSeamed,
  });

  final RideOffer offer;
  final OfferTakeoverState state;
  final TripRiderContext? riderContext;

  /// True once the #6 seam has RESOLVED to null (not merely still in flight) —
  /// the one condition under which the rider slot shows its designed rung.
  final bool riderSeamed;

  @override
  ConsumerState<_TakeoverCard> createState() => _TakeoverCardState();
}

class _TakeoverCardState extends ConsumerState<_TakeoverCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _payoutIn;
  bool _started = false;

  /// Payout stagger inside the card's 350ms entrance: hold ~150ms, then
  /// fade + rise over the remaining ~200ms.
  static const Curve _payoutInterval =
      Interval(0.43, 1, curve: Curves.easeOutCubic);

  /// The 12px rise the payout settles through.
  static const double _payoutRise = 12;

  @override
  void initState() {
    super.initState();
    // Duration-less in initState; the token resolves in
    // didChangeDependencies (05-02 controller convention).
    _entrance = AnimationController(vsync: this);
    _payoutIn = CurvedAnimation(parent: _entrance, curve: _payoutInterval);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _entrance.duration = context.hoppin.motion.offerEntrance;
    if (!_started) {
      _started = true;
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final state = widget.state;
    final rider = widget.riderContext;
    final riderSeamed = widget.riderSeamed;
    final notifier =
        ref.read(offerTakeoverInteractorProvider(widget.offer).notifier);

    // 🔴 THIS CARD STAYS OPAQUE. IT IS NOT AN OVERSIGHT — IT IS MEASURED.
    //
    // The glass pass converted every surface that floats over painted content,
    // and this one qualifies geometrically: it sits over the map, so a blur
    // would have something real to sample. It is still opaque, because the
    // contrast does not survive the conversion.
    //
    // A sheet-tier pane (86%) is PROVEN for body copy — but that proof assumes
    // a SCRIM behind the glass (`semantic_test`'s sheet case blends the page
    // through `colors.scrim` first, and that darkening is doing real work). The
    // takeover has NO scrim: the card sits straight over raw map tiles. Redoing
    // the same measurement for THIS composition — driver dark, worst case being
    // a bright tile passing under the card:
    //
    //   opaque (today)   hero 14.42:1   context line 6.42:1
    //   sheet  (86%)     hero  7.97:1   context line 3.55:1  ← under the 4.5 AA floor
    //   chrome (72%)     hero  5.06:1   context line 2.25:1  ← far under
    //
    // The hero fare would survive at the sheet tier. The context line under it
    // would not, and that line carries the distance and the ETA — half of what
    // the accept decision is actually made on.
    //
    // This is a 15-second decision, taken at a glance, often in daylight, by
    // someone about to drive. Trading legibility for frost here buys nothing a
    // driver can use and costs them the one screen where being wrong is
    // expensive. The material is not worth the read.
    //
    // If this is ever revisited: the knob is the FILL, not the text — do not
    // "fix" it by lifting textMid toward textHi, which flattens the locked
    // payout-first hierarchy the whole surface is built on.
    final card = Material(
      color: colors.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(hoppin.radii.sheet),
        ),
        side: BorderSide(color: colors.hairline),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            hoppin.spacing.gutter,
            hoppin.spacing.sm,
            hoppin.spacing.gutter,
            hoppin.spacing.gutter,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ghost Decline, quiet top-corner — its InkWell wins the
              // gesture arena over the card's tap-anywhere accept.
              Align(
                alignment: Alignment.centerRight,
                child: HopButton.ghost(
                  label: 'Decline',
                  expand: false,
                  onPressed: () => notifier.decline(),
                ),
              ),
              SizedBox(height: hoppin.spacing.sm),
              // The money is the message: fade + rise into place
              // (FadeTransition + transform — never an Opacity rebuild).
              FadeTransition(
                opacity: _payoutIn,
                child: AnimatedBuilder(
                  animation: _payoutIn,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _payoutRise * (1 - _payoutIn.value)),
                    child: child,
                  ),
                  child: _PayoutBlock(offer: widget.offer, rider: rider),
                ),
              ),
              SizedBox(height: hoppin.spacing.lg),
              // The rider slot. Seam #6 (SEAMED — the offer payload carries no
              // rider identity, so `tripRiderContext()` answers null on live):
              // once the seam RESOLVES null the slot degrades to the designed
              // RiderContextUnavailable rung rather than silently collapsing.
              // The job is untouched — payout, pickup and Accept are all real;
              // only WHO is unknown, and the rung says exactly that.
              //
              // The rider row keeps its 48px reserved slot (so the anatomy
              // below never shifts while the one-shot is in flight); the rung
              // is taller than a row by nature and takes the height it needs —
              // the loose Flexible on the context inset below is what yields
              // for it, exactly as it does for the error banner.
              if (rider != null)
                _RiderRow(rider: rider)
              else if (riderSeamed)
                const RiderContextUnavailable()
              else
                const SizedBox(height: 48),
              SizedBox(height: hoppin.spacing.lg),
              // Where the job is: compact driver→pickup context (MAP-04).
              // Inert, BELOW the money — the payout hero stays THE
              // dominant element; this only supports the call. Loose
              // Flexible: on short surfaces the INSET is what yields —
              // never the payout, the ring, or the locked spacing rhythm.
              //
              // 🔴 When a recoverable error banner is up, the inset yields
              // ENTIRELY: the banner is the message that matters, and keeping a
              // fixed-height map below it would push the locked anatomy off the
              // bottom of a short surface. Context is optional; the honest error
              // and the Accept ring are not.
              if (state.error == null) ...[
                Flexible(
                  child: _ContextInset(
                    driverPosition: state.driverContextPosition,
                    pickup: HopGeoPoint(
                      widget.offer.pickupLat,
                      widget.offer.pickupLng,
                    ),
                  ),
                ),
                SizedBox(height: hoppin.spacing.lg),
              ],
              if (state.error != null) ...[
                // Repo-call failures surface as the brand error banner.
                HopBanner.error(message: state.error!),
                SizedBox(height: hoppin.spacing.md),
              ],
              Center(
                child: _AcceptRing(
                  state: state,
                  busy: state.phase == OfferPhase.accepting,
                ),
              ),
              SizedBox(height: hoppin.spacing.sm),
            ],
          ),
        ),
      ),
    );

    // Tap-anywhere-to-accept (the Uber classic ping): the whole card body
    // is the big target; inner buttons win their own bounds.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => notifier.accept(),
      child: card,
    );
  }
}

/// The compact non-interactive driver→pickup map inset (MAP-04): fixed
/// height, clipped to the card radius under a hairline, fully inert —
/// context for the accept decision, never competition for the payout. A
/// null driver position renders a pickup-pin-only frame (the live rung).
class _ContextInset extends ConsumerWidget {
  const _ContextInset({required this.driverPosition, required this.pickup});

  /// One-shot context from the interactor's seam fetch; null on live.
  final HopGeoPoint? driverPosition;

  /// Pickup straight off the offer's own coordinates.
  final HopGeoPoint pickup;

  /// Compact by decree — tall enough to read, never a canvas. The parent's
  /// loose Flexible may hand down less on short surfaces; the SizedBox
  /// clamps to whatever remains after the locked anatomy takes its share.
  static const double _height = 120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final tileProvider = ref.watch(mapTileProvider);
    final radius = BorderRadius.circular(hoppin.radii.card);

    return SizedBox(
      height: _height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: colors.hairline),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: HopMap(
            // An inert map never re-frames after mount, so the arrival of
            // the one-shot driver position remounts it once for a fresh
            // driver+pickup framing (in demo that lands within the
            // entrance beat; in live it never comes and this stays put).
            key: ValueKey<bool>(driverPosition != null),
            pins: [HopMapPin(pickup, HopMapPinRole.pickup)],
            track: null,
            carPosition: driverPosition,
            carHeading: null,
            cameraIntent: FitPoints([?driverPosition, pickup]),
            follow: true,
            interactive: false,
            onUserGesture: _noop,
            userAgentPackageName: 'com.hoppin.driver',
            tileProvider: tileProvider,
          ),
        ),
      ),
    );
  }

  static void _noop() {}
}

/// Hero payout + context line — the top of the locked hierarchy.
class _PayoutBlock extends StatelessWidget {
  const _PayoutBlock({required this.offer, required this.rider});

  final RideOffer offer;
  final TripRiderContext? rider;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    final miles = '${offer.estimatedMiles.toStringAsFixed(1)} mi to pickup';
    final eta = rider?.pickupEtaSeconds;
    final contextLine = rider == null || eta == null
        ? miles
        : '${eta ~/ 60} min · $miles';

    return Column(
      children: [
        Text(
          '£${offer.fare.toStringAsFixed(2)}',
          // THE largest text on screen — the hero composition scales the
          // mono money style up (composition lives here, not in the type
          // scale).
          style: hoppin.type.moneyHero.copyWith(
            fontSize: 64,
            color: colors.textHi,
          ),
        ),
        SizedBox(height: hoppin.spacing.xs),
        Text(
          contextLine,
          style: hoppin.type.numeral.copyWith(color: colors.textMid),
        ),
      ],
    );
  }
}

/// Who is asking: initials, name, the rider's rating (never the driver's own)
/// and the latest comment about them.
class _RiderRow extends StatelessWidget {
  const _RiderRow({required this.rider});

  final TripRiderContext rider;

  String get _initials => rider.name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  String? get _ratingPill {
    if (rider.rating == null || rider.ratingCount <= 0) return null;
    if (rider.ratingCount > 1) {
      return '★ ${rider.rating!.toStringAsFixed(1)} (${rider.ratingCount})';
    }
    return '★ ${rider.rating!.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final comment = rider.recentComments.isNotEmpty
        ? rider.recentComments.first
        : null;
    final pill = _ratingPill;

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
                _initials,
                style: hoppin.type.label.copyWith(color: colors.accent),
              ),
            ),
          ),
        ),
        SizedBox(width: hoppin.spacing.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rider.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: hoppin.type.titleSmall.copyWith(color: colors.textHi),
              ),
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

/// The giant Accept: an accent disc inside the wall-clock CountdownRing,
/// the ring's numeric seconds ALWAYS visible under the label (never the
/// ring alone). Accepting swaps the label for the busy treatment.
class _AcceptRing extends StatelessWidget {
  const _AcceptRing({required this.state, required this.busy});

  final OfferTakeoverState state;
  final bool busy;

  static const double _size = 180;
  static const double _stroke = 6;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    final label = busy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: colors.onAccent,
            ),
          )
        : Text(
            'Accept',
            style: hoppin.type.title.copyWith(color: colors.onAccent),
          );

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The filled decision disc the ring drains around.
          SizedBox(
            width: _size - _stroke * 4,
            height: _size - _stroke * 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          CountdownRing(
            deadline: state.deadline,
            startedAt: state.presentedAt,
            size: _size,
            strokeWidth: _stroke,
            child: label,
          ),
        ],
      ),
    );
  }
}
