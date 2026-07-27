import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Fake-repository acceptance: six thin adapters over DemoWorld that honor
/// the exact contracts the screens already consume — above all the
/// BookingController's snapshot-then-poll id-diff matching flow.
void main() {
  DemoWorld riderWorld() =>
      DemoWorld.riderScenario(seed: DemoSeed.seed, store: InMemorySnapshotStore())
        ..restoreOrSeed();

  DemoWorld driverWorld() =>
      DemoWorld.driverScenario(seed: DemoSeed.seed, store: InMemorySnapshotStore())
        ..restoreOrSeed();

  /// Resolves a fake's Future synchronously under fake time — every fake
  /// wraps a synchronous world read, so a microtask flush must complete it.
  T resolve<T>(FakeAsync async, Future<T> future) {
    late T value;
    var done = false;
    future.then((v) {
      value = v;
      done = true;
    });
    async.flushMicrotasks();
    expect(done, isTrue, reason: 'fakes must not need real time to complete');
    return value;
  }

  /// Drains a void Future under fake time.
  void settle(FakeAsync async, Future<void> future) {
    var done = false;
    future.then((_) => done = true);
    async.flushMicrotasks();
    expect(done, isTrue, reason: 'fakes must not need real time to complete');
  }

  /// The error a fake's Future completes with, or null when it succeeds.
  Object? errorOf(FakeAsync async, Future<void> Function() call) {
    Object? error;
    call().then((_) {}, onError: (Object e) {
      error = e;
    });
    async.flushMicrotasks();
    return error;
  }

  Future<String> requestScriptedRide(FakeRidesRepository rides) =>
      rides.requestRide(
        pickupLat: DemoPlaces.scriptedPickup.lat,
        pickupLng: DemoPlaces.scriptedPickup.lng,
        dropoffLat: DemoPlaces.scriptedDropoff.lat,
        dropoffLng: DemoPlaces.scriptedDropoff.lng,
      );

  /// Runs the request through the match beat and returns the live ride id.
  String matchedRideId(FakeAsync async, FakeRidesRepository rides) {
    resolve(async, requestScriptedRide(rides));
    async.elapse(const Duration(seconds: 6));
    return resolve(async, rides.history(limit: 10)).first.id;
  }

  group('FakeRidesRepository', () {
    test('id-diff matching flow honors the BookingController contract', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);

        // The literal BookingController algorithm: snapshot ids first...
        final seen = resolve(async, rides.history(limit: 20))
            .map((r) => r.id)
            .toSet();
        // ...request (202: request_id only, never a ride id)...
        final requestId = resolve(async, requestScriptedRide(rides));
        expect(requestId, isNotEmpty);

        // ...poll: at 3s no unseen id may exist yet...
        async.elapse(const Duration(seconds: 3));
        final atThree = resolve(async, rides.history(limit: 10))
            .map((r) => r.id)
            .toSet()
            .difference(seen);
        expect(atThree, isEmpty,
            reason: 'match must not land before the 3s window opens');

        // ...at 6s exactly one unseen id, accepted, newest-first at index 0.
        async.elapse(const Duration(seconds: 3));
        final history = resolve(async, rides.history(limit: 10));
        final unseen = history.where((r) => !seen.contains(r.id)).toList();
        expect(unseen, hasLength(1));
        expect(unseen.single.status, RideStatus.accepted);
        expect(history.first.id, unseen.single.id,
            reason: 'the live ride must sit newest-first at index 0');
        expect(unseen.single.id, isNot(requestId));
      });
    });

    test('getRide reflects world transitions driven through the driver fake',
        () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final driver = FakeDriverRepository(world);
        final rideId = matchedRideId(async, rides);

        expect(resolve(async, rides.getRide(rideId)).status,
            RideStatus.accepted);

        settle(async, driver.markArrived(rideId));
        expect(resolve(async, rides.getRide(rideId)).status,
            RideStatus.arriving);

        settle(async, driver.startRide(rideId));
        expect(
            resolve(async, rides.getRide(rideId)).status, RideStatus.started);
      });
    });

    test('cancel accepts the four seeded reason uuids', () {
      for (final reasonId in DemoSeed.cancellationReasonIds) {
        FakeAsync().run((async) {
          final world = riderWorld()..markSignedIn();
          final rides = FakeRidesRepository(world);
          final rideId = matchedRideId(async, rides);

          settle(
            async,
            rides.cancel(
              rideId: rideId,
              reasonId: reasonId,
              canceledByUserId: DemoSeed.riderId,
              actorType: 'rider',
            ),
          );

          expect(resolve(async, rides.getRide(rideId)).status,
              RideStatus.cancelled);
          expect(world.phase, WorldPhase.idle,
              reason: 'a cancel must land the world cleanly back on idle');
        });
      }
    });

    test('cancel rejects unknown reason ids with 422 VALIDATION_FAILED', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        final error = errorOf(
          async,
          () => rides.cancel(
            rideId: rideId,
            reasonId: '00000000-0000-4000-8000-0000000000ff',
            canceledByUserId: DemoSeed.riderId,
            actorType: 'rider',
          ),
        );

        expect(
          error,
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.code, 'code', 'VALIDATION_FAILED'),
        );
        expect(resolve(async, rides.getRide(rideId)).status,
            RideStatus.accepted,
            reason: 'a rejected cancel must leave the ride untouched');
      });
    });

    test('applyPromo HOPPIN20 discounts, unknown code throws PROMO_NOT_FOUND',
        () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);

        final result = resolve(
          async,
          rides.applyPromo(rideId: rideId, promoCode: DemoSeed.promoCode),
        );
        expect(result.promoCode, DemoSeed.promoCode);
        expect(result.newFare, lessThan(result.originalFare));
        expect(result.discountAmount,
            closeTo(result.originalFare * 0.20, 0.011));

        final error = errorOf(
          async,
          () => rides.applyPromo(rideId: rideId, promoCode: 'NOTREAL'),
        );
        expect(
          error,
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', 'PROMO_NOT_FOUND'),
        );
      });
    });

    test('isPromoValid seam: true for the seeded code, false for unknown — '
        'never null in demo', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);

        expect(resolve(async, rides.isPromoValid(DemoSeed.promoCode)), isTrue);
        expect(resolve(async, rides.isPromoValid('hoppin20')), isTrue,
            reason: 'the check normalises case like applyPromo does');
        expect(resolve(async, rides.isPromoValid('NOTREAL')), isFalse);
      });
    });

    test('receipt returns an integer-pence Receipt for a completed ride', () {
      FakeAsync().run((async) {
        final world = riderWorld()..markSignedIn();
        final rides = FakeRidesRepository(world);
        final rideId = matchedRideId(async, rides);
        final quotedPence = (world
                    .estimateFor(
                      pickupLat: DemoPlaces.scriptedPickup.lat,
                      pickupLng: DemoPlaces.scriptedPickup.lng,
                      dropoffLat: DemoPlaces.scriptedDropoff.lat,
                      dropoffLng: DemoPlaces.scriptedDropoff.lng,
                    )
                    .estimate
                    .total *
                100)
            .round();

        // Play the whole scripted ride out (ETA + hold + trip + complete).
        async.elapse(const Duration(minutes: 6));
        expect(resolve(async, rides.getRide(rideId)).status,
            RideStatus.completed);

        final receipt = resolve(async, rides.receipt(rideId));
        expect(receipt.rideId, rideId);
        expect(receipt.status, 'paid');
        expect(receipt.totalPence, quotedPence);
        expect(receipt.farePence, quotedPence);
        expect(receipt.totalPence, inInclusiveRange(500, 1000),
            reason: 'scripted route must price inside the GBP 5-10 band');
        expect(receipt.platformCommissionPence, (quotedPence * 0.20).round());
      });
    });

    test('chat is off-script: messages empty, sendMessage unsupported', () {
      FakeAsync().run((async) {
        final rides = FakeRidesRepository(riderWorld());
        expect(resolve(async, rides.messages('any-ride')), isEmpty);
        expect(
          () => rides.sendMessage(rideId: 'any-ride', body: 'hi'),
          throwsUnsupportedError,
        );
      });
    });
  });

  group('FakeDriverRepository', () {
    test('offers loop delegates: online, offer, decline/re-offer, accept', () {
      FakeAsync().run((async) {
        final world = driverWorld()..markSignedIn();
        final driver = FakeDriverRepository(world);

        settle(async, driver.goOnline());
        expect(world.online, isTrue);
        expect(resolve(async, driver.offers()), isEmpty);

        async.elapse(const Duration(seconds: 6));
        final offer = resolve(async, driver.offers()).single;

        settle(async, driver.declineOffer(offer.offerId));
        expect(resolve(async, driver.offers()), isEmpty);

        async.elapse(const Duration(seconds: 5));
        final reoffer = resolve(async, driver.offers()).single;
        expect(reoffer.offerId, isNot(offer.offerId),
            reason: 're-offer must carry a fresh offer id');
        expect(reoffer.rideId, offer.rideId,
            reason: 're-offer must be the same trip');

        settle(async, driver.acceptOffer(reoffer.offerId));
        expect(world.phase, WorldPhase.accepted);
      });
    });

    test('goOffline kills the pending scripted request — no ghost offers', () {
      FakeAsync().run((async) {
        final world = driverWorld()..markSignedIn();
        final driver = FakeDriverRepository(world);

        settle(async, driver.goOnline());
        settle(async, driver.goOffline());
        expect(world.online, isFalse);

        async.elapse(const Duration(seconds: 10));
        expect(resolve(async, driver.offers()), isEmpty);
      });
    });

    test('acceptRide adopts the pending offer for the matching ride id', () {
      FakeAsync().run((async) {
        final world = driverWorld()..markSignedIn();
        final driver = FakeDriverRepository(world);
        settle(async, driver.goOnline());
        async.elapse(const Duration(seconds: 6));
        final offer = resolve(async, driver.offers()).single;

        settle(
          async,
          driver.acceptRide(rideId: offer.rideId, driverId: DemoSeed.driverId),
        );
        expect(world.phase, WorldPhase.accepted);

        // Tolerant: accepting an already-accepted ride is a quiet no-op.
        settle(
          async,
          driver.acceptRide(rideId: offer.rideId, driverId: DemoSeed.driverId),
        );
        expect(world.phase, WorldPhase.accepted);
      });
    });

    test('heartbeat and destination filter are calm no-ops', () {
      FakeAsync().run((async) {
        final driver = FakeDriverRepository(driverWorld());

        settle(async, driver.heartbeat(lat: 52.5877, lng: -2.1200));

        // The read is TYPED now (DestinationFilter, not a raw map) — so the
        // demo cannot answer with a count it invented either. It reports the
        // honest inactive state, and the counter stays null because no server
        // ever told it one.
        final before = resolve(async, driver.getDestinationFilter());
        expect(before.active, isFalse);
        expect(before.dailyUsesRemaining, isNull);

        settle(async, driver.setDestinationFilter(lat: 52.594, lng: -2.171));

        final after = resolve(async, driver.getDestinationFilter());
        expect(after.active, isFalse);
        expect(after.dailyUsesRemaining, isNull);

        settle(async, driver.clearDestinationFilter());
      });
    });

    test('todayStats surfaces seeded telemetry', () {
      FakeAsync().run((async) {
        final driver = FakeDriverRepository(driverWorld());

        final stats = resolve(async, driver.todayStats());
        expect(stats, isNotNull,
            reason: 'the demo fake must answer the capability seam');
        expect(stats!.online, isFalse);
        expect(stats.earningsPence, 4375);
        expect(stats.tripCount, 5);
        expect(
          stats.onlineTime,
          greaterThanOrEqualTo(const Duration(hours: 3, minutes: 10)),
        );
        expect(stats.pickupEtaSeconds, isNull);
        expect(stats.activeRideId, isNull);
      });
    });

    test('todayStats tracks the world live', () {
      FakeAsync().run((async) {
        final world = driverWorld()..markSignedIn();
        final driver = FakeDriverRepository(world);

        settle(async, driver.goOnline());
        expect(resolve(async, driver.todayStats())!.online, isTrue);

        // The scripted incoming request lands ~5s after going online.
        async.elapse(const Duration(seconds: 6));
        final offer = resolve(async, driver.offers()).single;
        settle(async, driver.acceptOffer(offer.offerId));

        var stats = resolve(async, driver.todayStats())!;
        expect(stats.pickupEtaSeconds, 120,
            reason: 'the ETA countdown starts the moment the offer accepts');
        expect(stats.activeRideId, offer.rideId,
            reason: 'an accepted ride is the driver\'s live trip');

        async.elapse(const Duration(seconds: 30));
        stats = resolve(async, driver.todayStats())!;
        expect(stats.pickupEtaSeconds, 90);

        settle(async, driver.markArrived(offer.rideId));
        settle(async, driver.startRide(offer.rideId));
        settle(async, driver.completeRide(offer.rideId));

        stats = resolve(async, driver.todayStats())!;
        expect(stats.earningsPence, 4375 + (offer.fare * 100).round(),
            reason: 'completion must tick earnings up by the payout');
        expect(stats.tripCount, 6);

        // Past the post-complete beat the live ride archives away.
        async.elapse(const Duration(milliseconds: 3500));
        expect(resolve(async, driver.todayStats())!.activeRideId, isNull);
      });
    });

    test('activeRideId ignores the un-accepted matching ride', () {
      FakeAsync().run((async) {
        final world = driverWorld()..markSignedIn();
        final driver = FakeDriverRepository(world);

        settle(async, driver.goOnline());
        async.elapse(const Duration(seconds: 6));

        expect(resolve(async, driver.offers()), hasLength(1),
            reason: 'the scripted offer must be pending');
        expect(resolve(async, driver.todayStats())!.activeRideId, isNull,
            reason: 'matching is the offer stage, not the driver\'s trip');
      });
    });

    test('tripRiderContext returns the scripted rider', () {
      FakeAsync().run((async) {
        final driver = FakeDriverRepository(driverWorld());

        final context = resolve(async, driver.tripRiderContext('demo-ride-id'));
        expect(context, isNotNull,
            reason: 'the demo fake must answer the capability seam');
        expect(context!.name, 'Sophie Bell');
        expect(context.rating, 4.8);
        expect(context.pickupLabel, 'Wolverhampton Rail Station');
        expect(context.pickupEtaSeconds, 120);
      });
    });
  });

  group('FakeProfileRepository', () {
    test('serves seeded saved locations and add/delete mutate in-session', () {
      FakeAsync().run((async) {
        final profile = FakeProfileRepository(riderWorld());

        final seeded = resolve(async, profile.savedLocations());
        expect(seeded.map((l) => l.label), ['Home', 'Work']);

        final added = resolve(
          async,
          profile.addSavedLocation(label: 'Gym', lat: 52.6006, lng: -2.0868),
        );
        expect(
          resolve(async, profile.savedLocations()).map((l) => l.label),
          ['Home', 'Work', 'Gym'],
        );

        settle(async, profile.deleteSavedLocation(added.id));
        expect(
          resolve(async, profile.savedLocations()).map((l) => l.label),
          ['Home', 'Work'],
        );
      });
    });

    test('contacts and device tokens are seeded constants / no-ops', () {
      FakeAsync().run((async) {
        final profile = FakeProfileRepository(riderWorld());

        expect(resolve(async, profile.emergencyContacts()), isEmpty);
        final contact = resolve(
          async,
          profile.addEmergencyContact(
            contactName: 'Anyone',
            phoneNumber: '07700 900123',
          ),
        );
        expect(contact.contactName, isNotEmpty);
        settle(async, profile.deleteEmergencyContact(contact.id));
        settle(
          async,
          profile.registerDeviceToken(fcmToken: 'tok', deviceOs: 'android'),
        );
      });
    });
  });

  group('FakePaymentsRepository', () {
    test('transactions match the seeded history receipts', () {
      FakeAsync().run((async) {
        final payments = FakePaymentsRepository(riderWorld());

        final txs = resolve(async, payments.transactions());
        expect(txs, hasLength(DemoHistory.trips.length));
        for (final tx in txs) {
          final receipt = DemoHistory.receiptsByRideId[tx.rideId];
          expect(receipt, isNotNull,
              reason: 'every seeded transaction must map to a history receipt');
          expect(tx.amountPence, receipt!.totalPence);
          expect(tx.status, 'paid');
        }
      });
    });

    test('one seeded Visa card; card mutations are off-script', () {
      FakeAsync().run((async) {
        final payments = FakePaymentsRepository(riderWorld());

        final cards = resolve(async, payments.paymentMethods());
        expect(cards, hasLength(1));
        expect(cards.single.brand, 'visa');
        expect(cards.single.last4, '4242');
        expect(cards.single.isDefault, isTrue);

        settle(async, payments.setDefault(cards.single.paymentMethodId));
        settle(async, payments.removeCard(cards.single.paymentMethodId));
        expect(() => payments.createSetupIntent(), throwsUnsupportedError);
      });
    });
  });

  group('FakeSafetyRepository / FakeSupportRepository', () {
    test('safety and support serve the off-script surface', () {
      FakeAsync().run((async) {
        const safety = FakeSafetyRepository();
        const support = FakeSupportRepository();

        expect(resolve(async, safety.raiseSos()), isNotEmpty);
        expect(resolve(async, safety.myEvents()), isEmpty);

        expect(
          resolve(async, support.createTicket(subject: 'Lost item')),
          isNotEmpty,
        );
        expect(resolve(async, support.myTickets()), isEmpty);
        expect(() => support.thread('any'), throwsUnsupportedError);
        settle(async, support.reply(ticketId: 'any', body: 'hello'));
      });
    });
  });
}
