import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_driver/providers.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// Acceptance for the driver app's reactive transport layer.
///
/// Every provider polls ONLY the repository interfaces, so a demo-scenario
/// [DemoWorld] behind [FakeDriverRepository]/[FakeRidesRepository] proves the
/// full loop under FakeAsync: stats stay ≤1s stale, the scripted offer
/// arrival/decline/re-offer beats surface within a tick, the ride stream
/// stops at terminal, and the rider context resolves one-shot.
void main() {
  DemoWorld driverWorld() => DemoWorld.driverScenario(
        seed: DemoSeed.seed,
        store: InMemorySnapshotStore(),
      )
        ..restoreOrSeed()
        ..markSignedIn();

  ProviderContainer containerOver(DemoWorld world) => ProviderContainer(
        overrides: [
          driverRepositoryProvider
              .overrideWithValue(FakeDriverRepository(world)),
          ridesRepositoryProvider.overrideWithValue(FakeRidesRepository(world)),
        ],
      );

  test('stats poll tracks the world within one tick', () {
    FakeAsync().run((async) {
      final world = driverWorld();
      final container = containerOver(world);
      final stats = <DriverDayStats>[];
      final sub = container.listen(driverStatsProvider, (_, next) {
        if (next.hasValue) stats.add(next.requireValue);
      });

      async.elapse(const Duration(milliseconds: 1500));
      expect(stats, isNotEmpty,
          reason: 'the first poll must land within one tick');
      expect(stats.last.earningsPence, 4375);
      expect(stats.last.online, isFalse);

      world.goOnline();
      async.elapse(const Duration(milliseconds: 1500));
      expect(stats.last.online, isTrue,
          reason: 'a world change must surface within one 1s poll tick');

      sub.close();
      container.dispose();
    });
  });

  test('offers poll carries arrival, decline-empty, and re-offer', () {
    FakeAsync().run((async) {
      final world = driverWorld()..goOnline();
      final container = containerOver(world);
      final offers = <List<RideOffer>>[];
      final sub = container.listen(pendingOffersProvider, (_, next) {
        if (next.hasValue) offers.add(next.requireValue);
      });

      // The scripted request lands ~5s after going online; one more poll
      // tick carries it into the provider.
      async.elapse(const Duration(seconds: 6));
      final offer = offers.last.single;
      expect(offer.fare, closeTo(6.39, 0.005),
          reason: 'the scripted route prices at GBP 6.39');

      world.declineOffer(offer.offerId);
      async.elapse(const Duration(milliseconds: 1500));
      expect(offers.last, isEmpty,
          reason: 'a decline must empty the pending list within a tick');

      // The re-offer fires ~4.2s after the decline.
      async.elapse(const Duration(seconds: 5));
      final reoffer = offers.last.single;
      expect(reoffer.offerId, isNot(offer.offerId),
          reason: 're-offer must carry a fresh offer id');
      expect(reoffer.rideId, offer.rideId,
          reason: 're-offer must be the same trip');

      sub.close();
      container.dispose();
    });
  });

  test('ride stream follows the lifecycle and stops at terminal', () {
    FakeAsync().run((async) {
      final world = driverWorld()..goOnline();
      async.elapse(const Duration(seconds: 6));
      final offer = world.pendingOffers().single;
      world.acceptOffer(offer.offerId);

      final container = containerOver(world);
      final statuses = <RideStatus>[];
      final sub =
          container.listen(driverRideStreamProvider(offer.rideId), (_, next) {
        if (!next.hasValue) return;
        final status = next.requireValue.status;
        if (statuses.isEmpty || statuses.last != status) statuses.add(status);
      });

      async.elapse(const Duration(milliseconds: 2500));
      expect(statuses, [RideStatus.accepted]);

      world.markArrived(offer.rideId);
      async.elapse(const Duration(milliseconds: 2500));
      expect(statuses.last, RideStatus.arriving);

      world.startRide(offer.rideId);
      async.elapse(const Duration(milliseconds: 2500));
      expect(statuses.last, RideStatus.started);

      world.completeRide(offer.rideId);
      async.elapse(const Duration(milliseconds: 2500));
      expect(statuses, [
        RideStatus.accepted,
        RideStatus.arriving,
        RideStatus.started,
        RideStatus.completed,
      ]);

      // Terminal reached: the stream closed — no emissions ever again.
      final settled = statuses.length;
      async.elapse(const Duration(seconds: 6));
      expect(statuses.length, settled,
          reason: 'the ride stream must stop polling at a terminal status');

      sub.close();
      container.dispose();
    });
  });

  test('rider context resolves once', () {
    FakeAsync().run((async) {
      final container = containerOver(driverWorld());
      TripRiderContext? context;
      final sub = container.listen(
          tripRiderContextProvider('demo-ride-id'), (_, next) {
        if (next.hasValue) context = next.requireValue;
      });

      async.flushMicrotasks();
      expect(context, isNotNull,
          reason: 'the one-shot context must resolve without wall time');
      expect(context!.name, 'Sophie Bell');
      expect(context!.rating, 4.8);
      expect(context!.pickupLabel, 'Wolverhampton Rail Station');
      expect(context!.pickupEtaSeconds, 120);

      sub.close();
      container.dispose();
    });
  });
}
