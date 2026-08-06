import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import '../../audio/offer_chime.dart';
import '../../providers.dart';
import 'dashboard_state.dart';
import 'eligibility_builder.dart';

/// THE BRAIN of the dashboard riblet (DOCS/05): merges world telemetry into
/// [DashboardState] and owns the go-online/go-offline/sign-out intents.
///
/// Telemetry flows IN via `ref.listen` on the 03-01 polling providers — the
/// interactor has no polling logic of its own. Online/offline is the
/// repository's state: intents flip the world and the next stats emission
/// flips the phase; nothing here is optimistic.
///
/// No Flutter widget imports, no BuildContext, no navigation — the router
/// listens to this state and navigates; the view renders it.
class DashboardInteractor extends Notifier<DashboardState> {
  /// Bumped on every user intent; in-flight async work from an older
  /// generation discards its result instead of clobbering fresh state
  /// (BookingController pattern).
  int _generation = 0;

  /// Clears [DashboardState.recentEarnedPence] after the absorb window.
  Timer? _absorbClear;

  /// How long the "+£x.xx" absorb delta stays armed before clearing —
  /// long enough for the chip rise (600ms) and the tile tick-up (700ms)
  /// to complete with margin.
  static const Duration absorbHold = Duration(milliseconds: 2500);

  @override
  DashboardState build() {
    ref.onDispose(() => _absorbClear?.cancel());

    // Telemetry in: today's trio + online truth, every ~1s.
    ref.listen(driverStatsProvider, (previous, next) {
      final stats = next.value;
      if (stats == null) return;
      _onStats(stats);
    });

    // The ACTIVE RIDE in, from a BOUND `GET /rides` read — never from the #7
    // telemetry seam. The router's trip-resume redirect acts on this, and
    // navigation may not hang off a value that is null on every live request.
    ref.listen(activeRideProvider, (previous, next) {
      if (!next.hasValue) return;
      _onActiveRide(next.value);
    });

    // A trip the driver has FINISHED WITH stops being a trip to resume, even
    // while the 2-second `GET /rides` poll is still catching up.
    ref.listen(dismissedRidesProvider, (previous, next) {
      final id = state.activeRideId;
      if (id != null && next.contains(id)) {
        state = state.copyWith(activeRideId: null);
      }
    });

    // Pending offers in: the interactor holds the head offer as truth;
    // the ROUTER attaches the takeover on it (03-05).
    ref.listen(pendingOffersProvider, (previous, next) {
      final offers = next.value;
      if (offers == null) return;
      state = state.copyWith(
        pendingOffer: offers.isEmpty ? null : offers.first,
      );
    });

    return const DashboardState();
  }

  /// The BOUND `GET /rides` answer → the trip-resume redirect's input.
  ///
  /// A ride the driver has already walked away from is NOT a ride to resume,
  /// no matter what the (2-second, lagging) poll still says about it. Without
  /// this filter the driver taps Done, lands on the dashboard, and the next
  /// stale poll tick throws them straight back into the trip they just left.
  void _onActiveRide(Ride? ride) {
    final dismissed = ref.read(dismissedRidesProvider);
    final id = ride == null || dismissed.contains(ride.id) ? null : ride.id;
    state = state.copyWith(activeRideId: id);
  }

  void _onStats(DriverDayStats stats) {
    // The world's online flag resolves the phase — unless a transition is
    // still in flight and the telemetry is stale for it.
    var phase = state.phase;
    if (stats.online && phase != DashboardPhase.goingOffline) {
      phase = DashboardPhase.online;
    } else if (!stats.online && phase != DashboardPhase.goingOnline) {
      phase = DashboardPhase.offline;
    }

    // Earnings increase on a warm stream arms the tile-absorb delta.
    // The very first emission never chips (no "+£43.75" on boot).
    var recentEarned = state.recentEarnedPence;
    if (state.statsReady && stats.earningsPence > state.earningsPence) {
      recentEarned = stats.earningsPence - state.earningsPence;
      _armAbsorbClear();
    }

    state = state.copyWith(
      phase: phase,
      earningsPence: stats.earningsPence,
      tripCount: stats.tripCount,
      onlineTime: stats.onlineTime,
      pickupEtaSeconds: stats.pickupEtaSeconds,
      // activeRideId is DELIBERATELY absent here. It is navigation state and
      // it is sourced from `activeRideProvider` (a BOUND `GET /rides` read).
      // Writing it from this handler would re-couple the trip-resume redirect
      // to the #7 seam, which never fires on live.
      recentEarnedPence: recentEarned,
      statsReady: true,
    );
  }

  void _armAbsorbClear() {
    _absorbClear?.cancel();
    _absorbClear = Timer(absorbHold, () {
      state = state.copyWith(recentEarnedPence: null);
    });
  }

  /// The GO tap. Guarded: only fires from a settled offline phase.
  ///
  /// PRESENCE IS AUTHORITATIVE FROM THE ENDPOINT, NOT FROM TELEMETRY. A 200
  /// from `POST /drivers/me/online` means the driver IS in the dispatch pool —
  /// that is the confirmation, and the phase flips on it.
  ///
  /// This used to hold at [DashboardPhase.goingOnline] and wait for the next
  /// `driverStatsProvider` emission to flip it. On live that emission NEVER
  /// COMES: `todayStats()` is a null capability seam (#7, no telemetry
  /// endpoint), so the stream never yields. The driver was left staring at a
  /// disabled spinner, unable to go offline (that affordance only renders when
  /// `phase == online`) — while already live in the dispatch pool taking
  /// offers. Wave-0 fix: never gate presence on a seam that can answer null.
  Future<void> goOnline() async {
    if (state.phase != DashboardPhase.offline) return;
    final gen = ++_generation;
    state = state.copyWith(phase: DashboardPhase.goingOnline, error: null);
    try {
      await ref.read(driverRepositoryProvider).goOnline();
      if (gen != _generation) return; // superseded by a newer intent
      // The 200 IS the confirmation. Telemetry, if it ever lands, only
      // decorates this state — it does not grant it.
      //
      // And ONLY this 200 may lift a `403 NOT_ELIGIBLE` the server itself
      // issued. The app never decides on its own that a refused driver has
      // become eligible again.
      ref.read(eligibilityInteractorProvider.notifier).onEligible();

      // OT-05 — arm the offer chime on a REAL, FRESH gesture.
      //
      // The login prime stays; this is the one that matters on Android, where a
      // driver's login is hours and a process-death behind their GO tap, and the
      // audio session it unlocked may be long gone. The chime is the OFFER
      // DELIVERY MECHANISM — the driver is looking at the road, not the screen,
      // and a silently-blocked chime is a missed offer, an unexplained decline,
      // and (per SF-05) a decline that silently cancels a rider's trip.
      //
      // Fire-and-forget, and deliberately so: prime() swallows everything and
      // returns quietly on a plugin-less platform. 🔴 NOTHING ABOUT AUDIO MAY
      // EVER GATE A SHIFT. A driver who cannot work because an AudioPlayer would
      // not initialise is exactly the class of defect this project has already
      // paid for once — a decoration that was allowed to decide. It sits AFTER
      // the 200 (never before) and BESIDE the presence flip, not inside a
      // seam-fed branch.
      unawaited(_primeChime());

      state = state.copyWith(phase: DashboardPhase.online);
    } on ApiException catch (e) {
      if (gen != _generation) return; // superseded by a newer intent
      // 🔴 BRANCH ON THE CODE, NEVER ON THE BARE STATUS. A 403 that is not
      // NOT_ELIGIBLE is an AUTH problem — showing an eligibility screen over an
      // expired session would send the driver off to re-upload compliance
      // paperwork to fix a token refresh. (409 in this codebase is BOTH
      // CHAT_CLOSED and ACTIVE_TRIP_EXISTS. The status number is not a
      // contract. The code is.)
      if (e.code == 'NOT_ELIGIBLE') {
        // 🔴 THE MESSAGE IS THE SERVER'S OR IT IS NOTHING. NOT_ELIGIBLE covers
        // compliance OR restriction OR suspension and the server does not say
        // which (#30). The rung admits that honestly; this interactor does not
        // get to invent a cause on its way past.
        ref
            .read(eligibilityInteractorProvider.notifier)
            .onNotEligible(e.message);
        // 🔴 `error: null` — the rung OWNS this message now. A red
        // friendlyErrorMessage banner AND an honest rung would tell the driver
        // the same thing twice, and the banner's version would be the vaguer
        // of the two.
        state = state.copyWith(phase: DashboardPhase.offline, error: null);
        return;
      }
      if (e.code == 'PAYOUT_NOT_READY') {
        // 403 — Stripe payout setup incomplete. Not a compliance issue, so
        // don't route to the eligibility rung; surface the server's message so
        // the driver knows to finish payout setup in Earnings before they can
        // go online and earn.
        state = state.copyWith(
          phase: DashboardPhase.offline,
          error: e.message.isNotEmpty
              ? e.message
              : 'Finish payout setup in Earnings to start earning.',
        );
        return;
      }
      state = state.copyWith(
        phase: DashboardPhase.offline,
        error: friendlyErrorMessage(e),
      );
    } on Exception catch (e) {
      if (gen != _generation) return; // superseded by a newer intent
      state = state.copyWith(
        phase: DashboardPhase.offline,
        error: friendlyErrorMessage(e),
      );
    }
  }

  /// The quiet secondary affordance — mirror image of [goOnline]. Same rule:
  /// the 200 is the confirmation, never a telemetry emission that may never
  /// arrive (seam #7).
  Future<void> goOffline() async {
    if (state.phase != DashboardPhase.online) return;
    final gen = ++_generation;
    state = state.copyWith(phase: DashboardPhase.goingOffline, error: null);
    try {
      await ref.read(driverRepositoryProvider).goOffline();
      if (gen != _generation) return;
      state = state.copyWith(phase: DashboardPhase.offline);
    } on Exception catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(
        phase: DashboardPhase.online,
        error: friendlyErrorMessage(e),
      );
    }
  }

  /// Arms the offer chime, swallowing ANY failure. The real [OfferChime.prime]
  /// already swallows internally; this belt-and-braces catch guarantees that
  /// even a fake or a future implementation that throws can NEVER escape into
  /// the goOnline path and block a shift. Audio is decoration; it never decides.
  Future<void> _primeChime() async {
    try {
      await ref.read(offerChimeProvider).prime();
    } catch (_) {
      // Audio unavailable — the visual offer entrance carries the beat alone.
    }
  }

  /// Sign-out intent. The AppRiblet's auth-gated redirect owns the
  /// navigation that follows — no context here, ever.
  Future<void> signOut() => ref.read(authServiceProvider).signOut();
}
