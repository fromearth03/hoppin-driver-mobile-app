import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/audio/offer_chime.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_builder.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_interactor.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_state.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart' show HopGeoPoint;

/// Interactor unit layer (riblet testing contract, DOCS/05): the offer
/// takeover's presenting/accepting/accepted/expired/dismissed machine —
/// chime-once at present, guarded accept/decline, the quiet wall-clock
/// expiry with its auto-decline recycle, and stale-timer protection —
/// proven under FakeAsync against recording fakes. No widgets, no world.
void main() {
  test('present plays the chime once, not again on state churn', () {
    FakeAsync().run((async) {
      final h = _Harness(_liveOffer(secondsOut: 45));
      async.flushMicrotasks();

      expect(h.state.phase, OfferPhase.presenting);
      expect(h.state.offer.offerId, 'offer-1');
      expect(h.chime.playCalls, 1,
          reason: 'the chime is the entrance beat — exactly once at present');

      // Unrelated state churn (a failed accept) must never replay it.
      h.repo.throwOnAccept = true;
      unawaited(h.interactor.accept());
      async.flushMicrotasks();
      expect(h.state.phase, OfferPhase.presenting);
      expect(h.chime.playCalls, 1);

      h.dispose();
    });
  });

  test('live-shaped timestamps are trusted as the countdown window', () {
    FakeAsync().run((async) {
      // A real backend's offer mid-window: offered 42s ago, 3s remaining.
      final offer = _offer(
        offeredAt: clock.now().subtract(const Duration(seconds: 42)),
        expiresAt: clock.now().add(const Duration(seconds: 3)),
      );
      final h = _Harness(offer);
      async.flushMicrotasks();

      expect(h.state.presentedAt, offer.offeredAt);
      expect(h.state.deadline, offer.expiresAt);

      h.dispose();
    });
  });

  test('virtual-clock timestamps re-anchor the window on the wall clock', () {
    FakeAsync().run((async) {
      // The demo world's data clock is anchored days in the past — a
      // literal expiresAt-vs-wall-clock diff would expire instantly. The
      // interactor re-anchors the offer's own 45s window at present.
      final staleOffered = clock.now().subtract(const Duration(days: 8));
      final offer = _offer(
        offeredAt: staleOffered,
        expiresAt: staleOffered.add(const Duration(seconds: 45)),
      );
      final now = clock.now();
      final h = _Harness(offer);
      async.flushMicrotasks();

      expect(h.state.phase, OfferPhase.presenting);
      expect(h.state.presentedAt, now);
      expect(h.state.deadline, now.add(const Duration(seconds: 45)));

      // And the expiry timer honours the re-anchored window, not zero.
      async.elapse(const Duration(seconds: 44));
      expect(h.state.phase, OfferPhase.presenting);
      async.elapse(const Duration(seconds: 2));
      expect(h.state.phase, OfferPhase.expired);

      h.dispose();
    });
  });

  test('accept delegates once and lands accepted', () {
    FakeAsync().run((async) {
      final h = _Harness(_liveOffer(secondsOut: 45));
      final gate = Completer<void>();
      h.repo.acceptGate = gate;

      unawaited(h.interactor.accept());
      async.flushMicrotasks();
      expect(h.repo.acceptCalls, 1);
      expect(h.repo.lastAcceptedOfferId, 'offer-1');
      expect(h.state.phase, OfferPhase.accepting);

      // Double-tap while in flight: the busy guard swallows it.
      unawaited(h.interactor.accept());
      async.flushMicrotasks();
      expect(h.repo.acceptCalls, 1);

      gate.complete();
      async.flushMicrotasks();
      expect(h.state.phase, OfferPhase.accepted);
      expect(h.state.acceptedRideId, 'ride-1');

      h.dispose();
    });
  });

  test('decline detaches', () {
    FakeAsync().run((async) {
      final h = _Harness(_liveOffer(secondsOut: 45));

      unawaited(h.interactor.decline());
      async.flushMicrotasks();
      expect(h.repo.declineCalls, 1);
      expect(h.repo.lastDeclinedOfferId, 'offer-1');
      expect(h.state.phase, OfferPhase.dismissed);

      // A second decline (or a late accept) is a no-op after dismissal.
      unawaited(h.interactor.decline());
      unawaited(h.interactor.accept());
      async.flushMicrotasks();
      expect(h.repo.declineCalls, 1);
      expect(h.repo.acceptCalls, 0);

      h.dispose();
    });
  });

  test('expiry is quiet and recycles', () {
    FakeAsync().run((async) {
      final h = _Harness(_liveOffer(secondsOut: 3));
      async.flushMicrotasks();

      // The wall-clock deadline passes: expired, but NO repo call yet —
      // the 'Offer expired' note beat plays first.
      async.elapse(const Duration(seconds: 3));
      expect(h.state.phase, OfferPhase.expired);
      expect(h.repo.declineCalls, 0);

      // After the note beat the recycle decline keeps the demo alive.
      async.elapse(OfferTakeoverInteractor.expiredNoteBeat +
          const Duration(milliseconds: 100));
      expect(h.repo.declineCalls, 1);
      expect(h.state.phase, OfferPhase.dismissed);

      h.dispose();
    });
  });

  test('stale expiry never fires after accept', () {
    FakeAsync().run((async) {
      final h = _Harness(_liveOffer(secondsOut: 3));
      async.flushMicrotasks();

      // Accept just before the deadline…
      async.elapse(const Duration(milliseconds: 2900));
      expect(h.state.phase, OfferPhase.presenting);
      unawaited(h.interactor.accept());
      async.flushMicrotasks();
      expect(h.state.phase, OfferPhase.accepted);

      // …then let the old deadline (and the note beat) pass: no expired
      // transition, no recycle decline — the timer died with the accept.
      async.elapse(const Duration(seconds: 5));
      expect(h.state.phase, OfferPhase.accepted);
      expect(h.repo.declineCalls, 0);

      h.dispose();
    });
  });

  test('the one-shot context fetch writes the driver position (MAP-04)', () {
    FakeAsync().run((async) {
      final h = _Harness(
        _liveOffer(secondsOut: 45),
        driverPosition: DriverPosition(
          lat: 52.5903,
          lng: -2.1306,
          updatedAt: clock.now(),
        ),
      );
      async.flushMicrotasks();

      expect(h.rides.positionCalls, 1);
      expect(h.rides.lastPositionRideId, 'ride-1');
      expect(
        h.state.driverContextPosition,
        const HopGeoPoint(52.5903, -2.1306),
      );

      // One-shot: no retry loop ever, even as the window drains.
      async.elapse(const Duration(seconds: 10));
      expect(h.rides.positionCalls, 1);

      h.dispose();
    });
  });

  test('a throwing context seam degrades to no position, never an error', () {
    FakeAsync().run((async) {
      final h = _Harness(_liveOffer(secondsOut: 45), throwOnPosition: true);
      async.flushMicrotasks();

      expect(h.state.phase, OfferPhase.presenting);
      expect(h.state.driverContextPosition, isNull);
      expect(h.state.error, isNull,
          reason: 'context is optional — its failure never surfaces');

      async.elapse(const Duration(seconds: 10));
      expect(h.rides.positionCalls, 1, reason: 'static context, no retries');

      h.dispose();
    });
  });

  test('accept failure is recoverable', () {
    FakeAsync().run((async) {
      final h = _Harness(_liveOffer(secondsOut: 45));
      h.repo.throwOnAccept = true;

      unawaited(h.interactor.accept());
      async.flushMicrotasks();
      expect(h.repo.acceptCalls, 1);
      expect(h.state.phase, OfferPhase.presenting);
      expect(h.state.error, 'Something went wrong. Please try again.');

      // The retry clears the error and completes.
      h.repo.throwOnAccept = false;
      unawaited(h.interactor.accept());
      async.flushMicrotasks();
      expect(h.state.error, isNull);
      expect(h.state.phase, OfferPhase.accepted);

      h.dispose();
    });
  });
}

/// A wall-clock-honest offer [secondsOut] from now, offered at now.
RideOffer _liveOffer({required int secondsOut}) => _offer(
      offeredAt: clock.now(),
      expiresAt: clock.now().add(Duration(seconds: secondsOut)),
    );

RideOffer _offer({
  required DateTime offeredAt,
  required DateTime expiresAt,
}) =>
    RideOffer(
      offerId: 'offer-1',
      rideId: 'ride-1',
      pickupLat: 52.5875,
      pickupLng: -2.1288,
      dropoffLat: 52.5906,
      dropoffLng: -2.0929,
      fare: 6.39,
      estimatedMiles: 1.7,
      expiresAt: expiresAt,
      offeredAt: offeredAt,
    );

/// Injected harness: the interactor sees ONLY recording repositories and a
/// recording chime; the family arg is the offer itself. The rides stub is
/// armed BEFORE the container listens — the one-shot context fetch starts
/// synchronously inside build().
class _Harness {
  _Harness(this.offer, {DriverPosition? driverPosition, bool throwOnPosition = false}) {
    rides
      ..position = driverPosition
      ..throwOnPosition = throwOnPosition;
    container = ProviderContainer(
      overrides: [
        driverRepositoryProvider.overrideWithValue(repo),
        ridesRepositoryProvider.overrideWithValue(rides),
        offerChimeProvider.overrideWithValue(chime),
      ],
    );
    // Keep the interactor actively listened (the view's ref.watch in
    // production) — Riverpod 3 pauses an unlistened provider.
    _sub = container.listen(offerTakeoverInteractorProvider(offer), (_, _) {});
  }

  final RideOffer offer;
  final repo = _RecordingDriverRepo();
  final rides = _StubRidesRepo();
  final chime = _RecordingChime();
  late final ProviderContainer container;
  late final ProviderSubscription<OfferTakeoverState> _sub;

  OfferTakeoverState get state =>
      container.read(offerTakeoverInteractorProvider(offer));

  OfferTakeoverInteractor get interactor =>
      container.read(offerTakeoverInteractorProvider(offer).notifier);

  void dispose() {
    _sub.close();
    container.dispose();
  }
}

/// Records prime/play without ever touching the audio plugin.
class _RecordingChime extends OfferChime {
  int primeCalls = 0;
  int playCalls = 0;

  @override
  Future<void> prime() async {
    primeCalls++;
  }

  @override
  Future<void> play() async {
    playCalls++;
  }
}

/// Records the offer intents; accept can be gated (in flight) or armed to
/// throw the 409 offer-expired shape. Only the members the interactor
/// touches are implemented.
class _RecordingDriverRepo implements DriverRepository {
  int acceptCalls = 0;
  int declineCalls = 0;
  String? lastAcceptedOfferId;
  String? lastDeclinedOfferId;
  Completer<void>? acceptGate;
  bool throwOnAccept = false;

  @override
  Future<void> acceptOffer(String offerId) {
    acceptCalls++;
    lastAcceptedOfferId = offerId;
    if (throwOnAccept) return Future.error(Exception('OFFER_EXPIRED'));
    return acceptGate?.future ?? Future.value();
  }

  @override
  Future<void> declineOffer(String offerId) {
    declineCalls++;
    lastDeclinedOfferId = offerId;
    return Future.value();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The MAP-04 context seam: records the one-shot driverPosition fetch and
/// can be armed to answer a position, null, or a transient throw.
class _StubRidesRepo implements RidesRepository {
  DriverPosition? position;
  bool throwOnPosition = false;
  int positionCalls = 0;
  String? lastPositionRideId;

  @override
  Future<DriverPosition?> driverPosition(String rideId) {
    positionCalls++;
    lastPositionRideId = rideId;
    if (throwOnPosition) return Future.error(Exception('telemetry down'));
    return Future.value(position);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
