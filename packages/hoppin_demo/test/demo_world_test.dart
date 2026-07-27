import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// DEMO-04 acceptance: the DemoWorld state machine is deterministic by
/// construction — same-seed runs play identically, matching lands inside the
/// locked 3-6s window, illegal transitions never corrupt state, and stale
/// timers never double-fire across interleaved taps.
void main() {
  DemoWorld riderWorld({int seed = 42}) =>
      DemoWorld.riderScenario(seed: seed, store: InMemorySnapshotStore())
        ..restoreOrSeed();

  DemoWorld driverWorld({int seed = 42}) =>
      DemoWorld.driverScenario(seed: seed, store: InMemorySnapshotStore())
        ..restoreOrSeed();

  String requestScriptedRide(DemoWorld world) => world.submitRideRequest(
        pickupLat: DemoPlaces.scriptedPickup.lat,
        pickupLng: DemoPlaces.scriptedPickup.lng,
        dropoffLat: DemoPlaces.scriptedDropoff.lat,
        dropoffLng: DemoPlaces.scriptedDropoff.lng,
      );

  /// Drives a driver-scenario world to an accepted live trip.
  (DemoWorld, String) driverAtAccepted(FakeAsync async) {
    final world = driverWorld()..markSignedIn();
    world.goOnline();
    async.elapse(const Duration(seconds: 6));
    final offer = world.pendingOffers().single;
    world.acceptOffer(offer.offerId);
    return (world, offer.rideId);
  }

  group('determinism', () {
    test('same seed plays identically', () {
      List<String> run() {
        late List<String> log;
        FakeAsync().run((async) {
          final world = riderWorld()..markSignedIn();
          requestScriptedRide(world);
          async.elapse(const Duration(minutes: 6));
          log = List.of(world.eventLog);
        });
        return log;
      }

      final first = run();
      final second = run();
      expect(first, isNotEmpty);
      expect(second, equals(first));
    });
  });

  group('matching beat', () {
    test('matching lands between 3 and 6 seconds', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final seededIds = world.rideHistory().map((r) => r.id).toSet();
        requestScriptedRide(world);

        async.elapse(const Duration(milliseconds: 2900));
        final earlyIds = world.rideHistory().map((r) => r.id).toSet();
        expect(
          earlyIds.difference(seededIds),
          isEmpty,
          reason: 'no ride row may exist before the 3s window opens',
        );

        async.elapse(const Duration(milliseconds: 3100));
        final fresh = world
            .rideHistory()
            .where((r) => !seededIds.contains(r.id))
            .toList();
        expect(fresh, hasLength(1));
        expect(fresh.single.status, RideStatus.accepted);
        expect(fresh.single.driverId, DemoSeed.driverId);
      });
    });

    test(
        'requestRide contract: request_id is not a ride id and history stays '
        'newest-first with the live ride at index 0', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final requestId = requestScriptedRide(world);
        expect(requestId, isNotEmpty);

        async.elapse(const Duration(seconds: 6));
        final history = world.rideHistory();
        expect(history.map((r) => r.id), isNot(contains(requestId)));
        expect(history.first.status, RideStatus.accepted);
        for (var i = 0; i < history.length - 1; i++) {
          expect(
            history[i].createdAt!.isAfter(history[i + 1].createdAt!),
            isTrue,
            reason: 'history must stay strictly newest-first',
          );
        }
      });
    });
  });

  group('transition legality', () {
    test('illegal transitions are ignored, never corrupt', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final phaseBefore = world.phase;
        final logBefore = List.of(world.eventLog);

        // No live ride exists: driver taps must be ignored outright.
        world.startRide(DemoHistory.rides.first.id);
        world.markArrived(DemoHistory.rides.first.id);
        world.completeRide(DemoHistory.rides.first.id);
        world.acceptOffer('no-such-offer');
        expect(world.phase, phaseBefore);
        expect(world.eventLog, logBefore);

        // With a live accepted ride, startRide is still illegal (the driver
        // has not arrived yet): the table lookup misses and state stays put.
        requestScriptedRide(world);
        async.elapse(const Duration(seconds: 6));
        expect(world.phase, WorldPhase.accepted);
        final liveId = world.rideHistory().first.id;
        final logAtAccepted = List.of(world.eventLog);
        world.startRide(liveId);
        expect(world.phase, WorldPhase.accepted);
        expect(world.eventLog, logAtAccepted);
        expect(world.rideById(liveId).status, RideStatus.accepted);
      });
    });

    test(
        'no double-fire on interleave: decline then offline cancels the '
        'stale re-offer timer', () {
      FakeAsync().run((async) {
        final world = driverWorld()..markSignedIn();
        world.goOnline();
        expect(world.online, isTrue);

        async.elapse(const Duration(seconds: 6));
        expect(world.pendingOffers(), hasLength(1));
        final offer = world.pendingOffers().single;

        world.declineOffer(offer.offerId);
        expect(world.pendingOffers(), isEmpty);
        world.goOffline();

        final logAfterOffline = List.of(world.eventLog);
        async.elapse(const Duration(seconds: 30));
        expect(
          world.eventLog,
          logAfterOffline,
          reason: 'no event may fire after going offline',
        );
        expect(world.phase, WorldPhase.idle);
        expect(world.online, isFalse);
        expect(world.pendingOffers(), isEmpty);
      });
    });
  });

  group('pacing', () {
    test('ETA counts down in real seconds and floors at Arriving now', () {
      FakeAsync().run((async) {
        final (world, rideId) = driverAtAccepted(async);
        expect(world.phase, WorldPhase.accepted);
        expect(world.etaSecondsRemaining, 120);

        async.elapse(const Duration(seconds: 30));
        expect(world.etaSecondsRemaining, 90);

        async.elapse(const Duration(seconds: 200));
        expect(world.etaSecondsRemaining, 0);
        expect(world.arrivingNow, isTrue);
        expect(world.phase, WorldPhase.arrivingHold);

        // The hold NEVER auto-advances: presenter pace cannot break it.
        async.elapse(const Duration(minutes: 10));
        expect(world.phase, WorldPhase.arrivingHold);
        expect(world.rideById(rideId).status, RideStatus.accepted);
        expect(world.etaSecondsRemaining, 0);
      });
    });

    test('driver arrived releases the hold', () {
      FakeAsync().run((async) {
        final (world, rideId) = driverAtAccepted(async);
        async.elapse(const Duration(seconds: 240)); // deep into the hold
        expect(world.phase, WorldPhase.arrivingHold);

        world.markArrived(rideId);
        expect(world.rideById(rideId).status, RideStatus.arriving);
        expect(world.phase, WorldPhase.arrived);

        world.startRide(rideId);
        expect(world.rideById(rideId).status, RideStatus.started);
        expect(world.phase, WorldPhase.inTrip);

        // Complete stays driver-tapped in this scenario — the in-trip
        // window passing on its own must not finish the ride.
        async.elapse(const Duration(seconds: 75));
        expect(world.rideById(rideId).status, RideStatus.started);

        world.completeRide(rideId);
        expect(world.rideById(rideId).status, RideStatus.completed);

        final receipt = world.receiptFor(rideId);
        final quote = quoteBetween(
          pickupLat: DemoPlaces.scriptedPickup.lat,
          pickupLng: DemoPlaces.scriptedPickup.lng,
          dropoffLat: DemoPlaces.scriptedDropoff.lat,
          dropoffLng: DemoPlaces.scriptedDropoff.lng,
        );
        expect(receipt.farePence, (quote.total * 100).round());
        expect(
          receipt.farePence + receipt.waitingPence,
          receipt.totalPence,
          reason: 'receipt must be pence-consistent',
        );
        expect(
          world.todayEarningsPence,
          DemoHistory.morningEarnings.totalPence + receipt.totalPence,
        );
        expect(
          world.todayTripCount,
          DemoHistory.morningEarnings.tripCount + 1,
        );
      });
    });

    test('rider scenario virtual driver runs the whole trip', () {
      FakeAsync().run((async) {
        final script = DemoScript.fromSeed(42);
        final world = riderWorld()..markSignedIn();
        requestScriptedRide(world);

        final totalMs = script.matchDelayMs +
            script.etaTotalSeconds * 1000 +
            script.virtualArriveHoldMs +
            script.virtualStartDelayMs +
            script.inTripSeconds * 1000;
        async.elapse(Duration(milliseconds: totalMs + 100));

        expect(world.phase, WorldPhase.completed);
        final liveId = world.rideHistory().first.id;
        expect(world.rideById(liveId).status, RideStatus.completed);

        // Each lifecycle state exactly once — no skip, no double-fire.
        expect(world.eventLog, [
          'idle>signedIn>idle',
          'idle>rideRequested>matching',
          'matching>rideMatched>accepted',
          'accepted>etaFloored>arrivingHold',
          'arrivingHold>driverArrived>arrived',
          'arrived>rideStarted>inTrip',
          'inTrip>rideCompleted>completed',
        ]);
      });
    });
  });

  group('recoverable loop', () {
    test('declined offer re-offers the same trip with a fresh offer id', () {
      FakeAsync().run((async) {
        final script = DemoScript.fromSeed(42);
        final world = driverWorld()..markSignedIn();
        world.goOnline();
        async.elapse(const Duration(seconds: 6));
        final offerA = world.pendingOffers().single;

        world.declineOffer(offerA.offerId);
        expect(world.pendingOffers(), isEmpty);

        async.elapse(Duration(milliseconds: script.reofferDelayMs + 100));
        final offerB = world.pendingOffers().single;
        expect(offerB.rideId, offerA.rideId);
        expect(offerB.fare, offerA.fare);
        expect(offerB.offerId, isNot(offerA.offerId));
      });
    });

    test('pre-match cancel returns cleanly to idle and allows rebooking', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        requestScriptedRide(world);
        async.elapse(const Duration(seconds: 6));
        final liveId = world.rideHistory().first.id;

        world.cancelRide(
          rideId: liveId,
          reasonId: DemoSeed.cancellationReasonIds.first,
          canceledByUserId: DemoSeed.riderId,
          actorType: 'rider',
        );
        expect(world.rideById(liveId).status, RideStatus.cancelled);
        expect(world.phase, WorldPhase.idle);
        expect(world.etaSecondsRemaining, isNull);

        // Immediate rebooking succeeds — no ghost timers, no ghost state.
        final secondRequest = requestScriptedRide(world);
        expect(secondRequest, isNotEmpty);
        async.elapse(const Duration(seconds: 6));
        final rebooked = world.rideHistory().first;
        expect(rebooked.id, isNot(liveId));
        expect(rebooked.status, RideStatus.accepted);
      });
    });

    test('cancel rejects unknown reason ids and leaves state unchanged', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        requestScriptedRide(world);
        async.elapse(const Duration(seconds: 6));
        final liveId = world.rideHistory().first.id;

        expect(
          () => world.cancelRide(
            rideId: liveId,
            reasonId: '11111111-1111-4111-8111-111111111111',
            canceledByUserId: DemoSeed.riderId,
            actorType: 'rider',
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 422)
                .having((e) => e.code, 'code', 'VALIDATION_FAILED'),
          ),
        );
        expect(world.phase, WorldPhase.accepted);
        expect(world.rideById(liveId).status, RideStatus.accepted);
      });
    });
  });

  group('promo', () {
    test('HOPPIN20 applies and the completed receipt reflects the discount',
        () {
      FakeAsync().run((async) {
        final script = DemoScript.fromSeed(42);
        final world = riderWorld()..markSignedIn();
        requestScriptedRide(world);
        async.elapse(const Duration(seconds: 6));
        final liveId = world.rideHistory().first.id;

        final result =
            world.applyPromoCode(rideId: liveId, promoCode: 'HOPPIN20');
        expect(result.discountType, 'percentage');
        expect(result.newFare, lessThan(result.originalFare));

        // Let the virtual driver finish the trip, then check the receipt.
        async.elapse(
          Duration(
            milliseconds: script.etaTotalSeconds * 1000 +
                script.virtualArriveHoldMs +
                script.virtualStartDelayMs +
                script.inTripSeconds * 1000 +
                100,
          ),
        );
        // RIDER-04/07: the discount must stay VISIBLE on the receipt —
        // farePence carries the pre-discount quote, totalPence what was
        // actually charged, so fare + waiting − total derives the discount.
        final receipt = world.receiptFor(liveId);
        expect(receipt.farePence, (result.originalFare * 100).round());
        expect(receipt.totalPence, (result.newFare * 100).round());
        expect(
          receipt.farePence + receipt.waitingPence - receipt.totalPence,
          (result.discountAmount * 100).round(),
          reason: 'the derived discount line must be pence-exact',
        );
        // Scripted route (seed 42): £6.39 quote, 20% off → £5.11 / −£1.28.
        expect(receipt.farePence, 639);
        expect(receipt.totalPence, 511);
      });
    });

    test('promo receipt keeps the money trail on the charged amount', () {
      FakeAsync().run((async) {
        final script = DemoScript.fromSeed(42);
        final world = riderWorld()..markSignedIn();
        final earningsBefore = world.todayEarningsPence;
        requestScriptedRide(world);
        async.elapse(const Duration(seconds: 6));
        final liveId = world.rideHistory().first.id;
        world.applyPromoCode(rideId: liveId, promoCode: 'HOPPIN20');

        async.elapse(
          Duration(
            milliseconds: script.etaTotalSeconds * 1000 +
                script.virtualArriveHoldMs +
                script.virtualStartDelayMs +
                script.inTripSeconds * 1000 +
                100,
          ),
        );
        final receipt = world.receiptFor(liveId);
        // Transactions and earnings follow the DISCOUNTED total — the
        // money actually taken — never the pre-discount fare.
        final tx = world
            .transactions()
            .where((t) => t.rideId == liveId)
            .single;
        expect(tx.amountPence, receipt.totalPence);
        expect(
          world.todayEarningsPence,
          earningsBefore + receipt.totalPence,
        );
        // Commission follows the charged amount too (plan-check decision).
        expect(
          receipt.platformCommissionPence,
          (receipt.totalPence * 0.20).round(),
        );
      });
    });

    test('no-promo receipt stays fare == total', () {
      FakeAsync().run((async) {
        final script = DemoScript.fromSeed(42);
        final world = riderWorld()..markSignedIn();
        requestScriptedRide(world);
        async.elapse(const Duration(seconds: 6));
        final liveId = world.rideHistory().first.id;

        async.elapse(
          Duration(
            milliseconds: script.etaTotalSeconds * 1000 +
                script.virtualArriveHoldMs +
                script.virtualStartDelayMs +
                script.inTripSeconds * 1000 +
                100,
          ),
        );
        final receipt = world.receiptFor(liveId);
        expect(receipt.farePence, 639);
        expect(receipt.totalPence, 639);
        expect(receipt.farePence + receipt.waitingPence, receipt.totalPence);
      });
    });

    test(
        'archived session ride keeps its journey labels for history and '
        'receipt continuity', () {
      FakeAsync().run((async) {
        final script = DemoScript.fromSeed(42);
        final world = riderWorld()..markSignedIn();
        requestScriptedRide(world);

        // Play the whole script INCLUDING the 3s post-complete archive beat.
        final totalMs = script.matchDelayMs +
            script.etaTotalSeconds * 1000 +
            script.virtualArriveHoldMs +
            script.virtualStartDelayMs +
            script.inTripSeconds * 1000;
        async.elapse(Duration(milliseconds: totalMs + 100));
        final rideId = world.rideHistory().first.id;
        async.elapse(Duration(milliseconds: script.postCompleteMs + 100));
        expect(world.phase, WorldPhase.idle,
            reason: 'the ride must be archived before this assertion');

        // The seam still serves the identity AND the journey labels — the
        // history Activity-hub row and the receipt strip both read them
        // after the archive beat. Telemetry (ETA) stays dropped.
        final info = world.driverInfoFor(rideId);
        expect(info, isNotNull);
        expect(info!.fullName, 'Gurpreet Singh');
        expect(info.etaSeconds, isNull);
        expect(info.originLabel, 'Wolverhampton Rail Station');
        expect(info.destinationLabel, 'New Cross Hospital');
      });
    });

    test('unknown promo code throws the PROMO_NOT_FOUND shape', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        requestScriptedRide(world);
        async.elapse(const Duration(seconds: 6));
        final liveId = world.rideHistory().first.id;

        expect(
          () => world.applyPromoCode(rideId: liveId, promoCode: 'NOPE50'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having((e) => e.code, 'code', 'PROMO_NOT_FOUND'),
          ),
        );
        expect(world.phase, WorldPhase.accepted);
      });
    });
  });
}
