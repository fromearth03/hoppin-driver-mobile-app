import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart' show HopGeoPoint;

import '../../audio/offer_chime.dart';
import 'offer_takeover_state.dart';

/// THE BRAIN of the offer takeover riblet (DOCS/05): a per-offer state
/// machine keyed by the offer itself (family arg via constructor,
/// Riverpod 3 — freezed value equality makes the offer its own key).
///
/// Present plays the entrance chime (primed since the login tap) and arms
/// the wall-clock expiry timer; accept/decline are guarded intents through
/// the repository; expiry is QUIET — the note beat plays, then the recycle
/// decline keeps the demo alive (the world re-offers per script).
///
/// No Flutter widget imports, no BuildContext, no navigation — the router
/// listens to this state and attaches/detaches; the view renders it.
class OfferTakeoverInteractor extends Notifier<OfferTakeoverState> {
  OfferTakeoverInteractor(this.offer);

  /// The family argument: the offer this takeover presents.
  final RideOffer offer;

  /// Bumped on every user intent AND on dispose; in-flight async work from
  /// an older generation discards its result instead of clobbering fresh
  /// (or dead) state (BookingController pattern).
  int _generation = 0;

  /// Fires when the wall-clock deadline passes while still presenting.
  Timer? _expiry;

  /// The 'Offer expired' note beat between expired and the recycle decline.
  Timer? _noteBeat;

  /// How long the quiet 'Offer expired' note stays up before the recycle
  /// decline dismisses the takeover.
  static const Duration expiredNoteBeat = Duration(milliseconds: 1200);

  @override
  OfferTakeoverState build() {
    ref.onDispose(() {
      _generation++;
      _cancelTimers();
    });

    final now = clock.now();
    final window = offer.expiresAt.difference(offer.offeredAt);
    final remaining = offer.expiresAt.difference(now);

    // Wall-clock anchoring: a live backend's timestamps are wall-clock
    // truth mid-window — trust them as-is. Timestamps NOT comparable to
    // the wall clock (already behind it, or further out than the offer's
    // own window — the demo world's data clock is anchored in the past)
    // re-anchor the offer's full window at present, so the ring and the
    // expiry timer always render the engine's real expiry span.
    final trusted = remaining > Duration.zero && remaining <= window;

    // 🔴 RECOMPUTE EXPIRY FROM clock.now() — NEVER TRUST THAT A TIMER FIRED.
    // A real, recent offer whose deadline is already in the past is EXPIRED,
    // and it must be REMOVED, not greyed. This is the Android resume case: the
    // takeover was presenting, the app backgrounded, the OS CLAMPED the expiry
    // timer so it never fired, and the driver returns to a dead card that a
    // timer-only model would still show as live. The signal is the offer's own
    // recency: a genuinely-recent offer (offeredAt within a plausible wall-clock
    // reach of now) with a past deadline is real expiry; a demo offer whose
    // whole window sits DAYS behind the wall clock is a data-clock artifact and
    // re-anchors below instead.
    final genuinelyExpired = !trusted &&
        remaining <= Duration.zero &&
        now.difference(offer.offeredAt) <= const Duration(hours: 1);

    final presentedAt = trusted ? offer.offeredAt : now;
    final deadline = trusted
        ? offer.expiresAt
        : now.add(window.isNegative ? Duration.zero : window);

    if (genuinelyExpired) {
      // Present straight into the quiet expired note → recycle decline. No
      // chime, no card, no timers armed toward a deadline already behind us —
      // the recycle beat runs and the takeover dismisses to the dashboard.
      _noteBeat = Timer(
        expiredNoteBeat,
        () => unawaited(_recycleExpired()),
      );
      return OfferTakeoverState(
        offer: offer,
        presentedAt: presentedAt,
        deadline: deadline,
        phase: OfferPhase.expired,
      );
    }

    // The entrance beat — fire-and-forget, throw-proof, primed since the
    // login tap (Chrome gesture unlock).
    unawaited(ref.read(offerChimeProvider).play());

    // Visual expiry is THIS wall-clock call — the world never expires the
    // offer itself; expiresAt is data.
    var untilDeadline = deadline.difference(now);
    if (untilDeadline.isNegative) untilDeadline = Duration.zero;
    _expiry = Timer(untilDeadline, _onExpiry);

    // MAP-04 inset context: ONE null-tolerant driver-position fetch (the
    // demo world serves the approach spawn for the offered ride while
    // matching; live answers null until the driver-location read ships).
    // Static context — never a retry loop; the generation guard drops a
    // landing that arrives after any intent or dispose.
    unawaited(_fetchDriverContext(
      ref.read(ridesRepositoryProvider),
      _generation,
    ));

    return OfferTakeoverState(
      offer: offer,
      presentedAt: presentedAt,
      deadline: deadline,
    );
  }

  /// The one-shot MAP-04 context fetch. Null answers and transient throws
  /// both mean "no context" — the inset renders pickup-pin-only; the
  /// payout decision never waits on geography.
  Future<void> _fetchDriverContext(RidesRepository rides, int gen) async {
    DriverPosition? position;
    try {
      position = await rides.driverPosition(offer.rideId);
    } on Exception {
      position = null;
    }
    if (position == null || gen != _generation) return;
    state = state.copyWith(
      driverContextPosition: HopGeoPoint(position.lat, position.lng),
    );
  }

  /// The big tap (button, ring, or anywhere on the card). Guarded to
  /// presenting; failure is recoverable — a friendly message and the
  /// window keeps draining.
  Future<void> accept() async {
    if (state.phase != OfferPhase.presenting) return;
    final gen = ++_generation;
    final repo = ref.read(driverRepositoryProvider);
    state = state.copyWith(phase: OfferPhase.accepting, error: null);
    try {
      await repo.acceptOffer(offer.offerId);
      if (gen != _generation) return; // superseded, rebuilt, or disposed
      _cancelTimers();
      state = state.copyWith(
        phase: OfferPhase.accepted,
        acceptedRideId: offer.rideId,
      );
    } on ApiException catch (e) {
      if (gen != _generation) return;
      // 🔴 BRANCH ON e.code, NEVER ON THE BARE STATUS. 403 is BOTH NOT_ELIGIBLE
      // (a compliance event) AND FORBIDDEN (this offer belongs to another
      // driver); 409 is BOTH OFFER_EXPIRED AND CHAT_CLOSED. The status number is
      // not a contract — the code is.
      switch (e.code) {
        // 🔴 THE DRIVER DID THEIR JOB. THE NETWORK DIDN'T.
        // They tapped inside the window; the round-trip lost the race. A red
        // toast blames them for our latency and then leaves them on a card that
        // will never do anything again. This is a specific, non-blaming state,
        // and the router puts them back on the dashboard STILL ONLINE.
        case 'OFFER_EXPIRED':
          _cancelTimers();
          state = state.copyWith(phase: OfferPhase.reassigned);
          // The non-blaming state holds for a short, readable beat — the SAME
          // rhythm as the quiet expired note, never a second invented cadence —
          // then dismisses, and the router's pop lands the driver back on the
          // dashboard, still online.
          _noteBeat = Timer(
            expiredNoteBeat,
            () => _dismissReassigned(gen),
          );

        // 🔴 A COMPLIANCE EVENT, AND WE DO NOT KNOW WHICH ONE.
        // The server re-checks eligibility AT ACCEPT, so an MOT that expired
        // mid-shift lands here. But NOT_ELIGIBLE is returned for compliance OR
        // restriction OR suspension — three different things, three different
        // driver actions, one opaque code (#30). The router routes to Documents
        // because it is the one place they can ACT, and we say NOTHING about the
        // cause. Any string mapped from NOT_ELIGIBLE is a defect: telling a
        // suspended driver their paperwork is out of date sends them to
        // re-upload a valid MOT and wait for a change that will never come.
        case 'NOT_ELIGIBLE':
          _cancelTimers();
          state = state.copyWith(phase: OfferPhase.notEligible);

        // Everything else — FORBIDDEN (this offer is another driver's),
        // ILLEGAL_TRANSITION, an unknown code — is RECOVERABLE. Back to
        // presenting, a friendly line, the window keeps draining. An
        // unrecognised code is IGNORANCE, and ignorance must never harden into a
        // terminal state that strands the driver.
        default:
          state = state.copyWith(
            phase: OfferPhase.presenting,
            error: friendlyErrorMessage(e),
          );
      }
    } on Exception catch (e) {
      if (gen != _generation) return;
      // A transport failure with no code is recoverable, exactly as before.
      state = state.copyWith(
        phase: OfferPhase.presenting,
        error: friendlyErrorMessage(e),
      );
    }
  }

  /// The quiet ghost tap. Dismisses immediately (the slide-away never
  /// waits on the network); the decline call is a quiet notification —
  /// the world re-offers the same trip per script.
  Future<void> decline() async {
    if (state.phase != OfferPhase.presenting) return;
    _generation++;
    _cancelTimers();
    final repo = ref.read(driverRepositoryProvider);
    state = state.copyWith(phase: OfferPhase.dismissed);
    try {
      await repo.declineOffer(offer.offerId);
    } on Exception {
      // Quiet — the takeover already slid away.
    }
  }

  /// Deadline passed while still presenting: the quiet expired note, then
  /// the recycle.
  void _onExpiry() {
    if (state.phase != OfferPhase.presenting) return;
    state = state.copyWith(phase: OfferPhase.expired);
    _noteBeat = Timer(expiredNoteBeat, () => unawaited(_recycleExpired()));
  }

  /// The recycle that keeps the demo alive: an expired offer is declined
  /// on the driver's behalf so the world re-dispatches, and the takeover
  /// dismisses without ever showing red.
  Future<void> _recycleExpired() async {
    if (state.phase != OfferPhase.expired) return;
    final repo = ref.read(driverRepositoryProvider);
    state = state.copyWith(phase: OfferPhase.dismissed);
    try {
      await repo.declineOffer(offer.offerId);
    } on Exception {
      // Quiet — expiry is never a failure state.
    }
  }

  /// After the reassigned beat: dismiss so the router pops the overlay and the
  /// driver lands back on the dashboard. Generation-guarded — a retry or a
  /// dispose between the beat arming and firing discards this.
  void _dismissReassigned(int gen) {
    if (gen != _generation) return;
    if (state.phase != OfferPhase.reassigned) return;
    state = state.copyWith(phase: OfferPhase.dismissed);
  }

  void _cancelTimers() {
    _expiry?.cancel();
    _noteBeat?.cancel();
  }
}
