import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_demo/hoppin_demo.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// DEMO-06 acceptance: reset re-seeds synchronously in one call, a mid-ride
/// snapshot resumes exactly (including remaining timer durations), a fresh
/// boot lands signed out, and garbage snapshots are discarded quietly.
void main() {
  String requestScriptedRide(DemoWorld world) => world.submitRideRequest(
        pickupLat: DemoPlaces.scriptedPickup.lat,
        pickupLng: DemoPlaces.scriptedPickup.lng,
        dropoffLat: DemoPlaces.scriptedDropoff.lat,
        dropoffLng: DemoPlaces.scriptedDropoff.lng,
      );

  test('fresh boot seeds signed-out', () {
    FakeAsync().run((_) {
      final world = DemoWorld.riderScenario(
        seed: 42,
        store: InMemorySnapshotStore(),
      )..restoreOrSeed();

      expect(world.signedIn, isFalse);
      expect(world.phase, WorldPhase.idle);
      expect(
        world.rideHistory().map((r) => r.id),
        DemoHistory.rides.map((r) => r.id),
        reason: 'a fresh boot serves exactly the seeded history',
      );
      expect(world.todayEarningsPence, 4375);
    });
  });

  test('F5 mid-ride resumes exactly, including the remaining ETA', () {
    FakeAsync().run((async) {
      final store = InMemorySnapshotStore();
      final script = DemoScript.fromSeed(42);
      final worldA = DemoWorld.riderScenario(seed: 42, store: store)
        ..restoreOrSeed()
        ..markSignedIn();
      requestScriptedRide(worldA);
      async.elapse(Duration(milliseconds: script.matchDelayMs));
      expect(worldA.phase, WorldPhase.accepted);
      async.elapse(const Duration(seconds: 30));
      expect(worldA.etaSecondsRemaining, 90);
      final liveId = worldA.rideHistory().first.id;

      // The "F5": a second world boots over the SAME store.
      final worldB = DemoWorld.riderScenario(seed: 42, store: store)
        ..restoreOrSeed();
      expect(worldB.signedIn, isTrue);
      expect(worldB.phase, WorldPhase.accepted);
      expect(worldB.rideHistory().first.id, liveId);
      expect(
        (worldB.etaSecondsRemaining! - worldA.etaSecondsRemaining!).abs(),
        lessThanOrEqualTo(1),
        reason: 'the restored countdown must be within 1s of the original',
      );

      // The re-armed countdown floors after its REMAINING duration — not a
      // fresh 120s.
      async.elapse(const Duration(seconds: 90));
      expect(worldB.phase, WorldPhase.arrivingHold);
      expect(worldB.arrivingNow, isTrue);
    });
  });

  test('reset returns to start in one synchronous call', () {
    FakeAsync().run((async) {
      final store = InMemorySnapshotStore();
      final world = DemoWorld.riderScenario(seed: 42, store: store)
        ..restoreOrSeed()
        ..markSignedIn();
      requestScriptedRide(world);
      async.elapse(const Duration(seconds: 30));
      expect(world.phase, WorldPhase.accepted);
      expect(store.read(), isNotNull);

      world.reset();

      // Assert immediately — no pump, no elapse: reset is synchronous.
      expect(store.read(), isNull);
      expect(world.signedIn, isFalse);
      expect(world.phase, WorldPhase.idle);
      expect(world.eventLog, isEmpty);
      expect(
        world.rideHistory().map((r) => r.id),
        DemoHistory.rides.map((r) => r.id),
      );
      expect(world.todayEarningsPence, 4375);

      // The full opening loop works again after reset.
      world.markSignedIn();
      requestScriptedRide(world);
      async.elapse(const Duration(seconds: 6));
      expect(world.phase, WorldPhase.accepted);
      expect(world.rideHistory().first.status, RideStatus.accepted);
    });
  });

  test('corrupt or version-mismatched snapshot is discarded', () {
    FakeAsync().run((_) {
      final corrupt = InMemorySnapshotStore()..write('{"not even": "json"');
      final worldA = DemoWorld.riderScenario(seed: 42, store: corrupt)
        ..restoreOrSeed();
      expect(worldA.phase, WorldPhase.idle);
      expect(worldA.signedIn, isFalse);
      expect(worldA.rideHistory(), hasLength(7));

      final mismatched = InMemorySnapshotStore()
        ..write(jsonEncode({'version': 999, 'seed': 42, 'scenario': 'rider'}));
      final worldB = DemoWorld.riderScenario(seed: 42, store: mismatched)
        ..restoreOrSeed();
      expect(worldB.phase, WorldPhase.idle);
      expect(worldB.signedIn, isFalse);
      expect(worldB.rideHistory(), hasLength(7));

      // A snapshot written by a different-seed world is not adopted either.
      final foreign = InMemorySnapshotStore();
      DemoWorld.riderScenario(seed: 7, store: foreign)
        ..restoreOrSeed()
        ..markSignedIn();
      final worldC = DemoWorld.riderScenario(seed: 42, store: foreign)
        ..restoreOrSeed();
      expect(worldC.signedIn, isFalse);
      expect(worldC.phase, WorldPhase.idle);
    });
  });
}
