import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_builder.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_interactor.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_state.dart';
import 'package:hoppin_driver/features/offer_takeover/offer_takeover_view.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_interactor.dart';
import 'package:hoppin_driver/features/trip/trip_runner_state.dart';
import 'package:hoppin_driver/features/trip/trip_runner_view.dart';
import 'package:hoppin_driver/providers.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../../support/no_network_tile_provider.dart';

/// View layer of the driver map riblet (riblet testing contract, DOCS/05) —
/// MAP-04's render proofs on the REAL interactor over stubbed geo seams:
///
/// - The trip runner carries the full-bleed nav canvas: HopMap behind the
///   morphing card, heading marker present, objective chip showing the
///   pickup-flavored label + along-leg distance.
/// - Driving the runner to started flips chip AND pin to the destination —
///   the view renders the interactor's atomic objective flip.
/// - Both seams null → NO HopMap in the runner tree (the live-mode
///   regression lock: the canvas-less Phase 3 layout survives exactly).
/// - The offer takeover inset is fully inert (IgnorePointer + interactive
///   false — a drag dispatches nothing) and the payout hero stays THE
///   largest text on screen with the map present.
///
/// Bounded pumps only (marker tween + chase camera never settle); tiles are
/// served from memory through the mapTileProvider seam — zero HTTP.
void main() {
  // The interactor suite's Wolverhampton-shaped stub geometry.
  const spawn = GeoPoint(lat: 52.5903, lng: -2.1306);
  const approachMid = GeoPoint(lat: 52.5890, lng: -2.1200);
  const pickup = GeoPoint(lat: 52.5877, lng: -2.1200);
  const routeMid = GeoPoint(lat: 52.5960, lng: -2.1060);
  const dropoff = GeoPoint(lat: 52.6046, lng: -2.0930);

  const approachLeg = [spawn, approachMid, pickup];
  const routeLeg = [pickup, routeMid, dropoff];

  RideGeo stubGeo() => RideGeo(
        pickupLat: pickup.lat,
        pickupLng: pickup.lng,
        dropoffLat: dropoff.lat,
        dropoffLng: dropoff.lng,
        route: routeLeg,
        approach: approachLeg,
      );

  DriverPosition positionAt(GeoPoint point, {double? heading}) =>
      DriverPosition(
        lat: point.lat,
        lng: point.lng,
        heading: heading,
        updatedAt: clock.now(),
      );

  HopGeoPoint hop(GeoPoint p) => HopGeoPoint(p.lat, p.lng);

  /// The chip's exact rendering pipeline: haversine sum → round to int
  /// meters (interactor) → miles to 1dp (view).
  String chipDistance(List<GeoPoint> legFromCar) {
    var meters = 0.0;
    for (var i = 0; i < legFromCar.length - 1; i++) {
      meters += _haversineMeters(hop(legFromCar[i]), hop(legFromCar[i + 1]));
    }
    return '${(meters.round() / 1609.344).toStringAsFixed(1)} mi';
  }

  Future<_StubRunner> pumpRunner(
    WidgetTester tester,
    _GeoRepo repo, {
    ThemeData? theme,
  }) async {
    final runner = _StubRunner();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ridesRepositoryProvider.overrideWithValue(repo),
        tripRunnerInteractorProvider.overrideWith2((rideId) => runner),
        mapTileProvider.overrideWithValue(NoNetworkTileProvider()),
      ],
      child: MaterialApp(
        theme: theme ?? HoppinTheme.driverDark(),
        home: const TripRunnerView(rideId: 'ride-1'),
      ),
    ));
    // First poll lands in microtasks; the canvas mounts on the next frame.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return runner;
  }

  Future<void> settleMorph(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('trip runner nav canvas', () {
    testWidgets(
        'headingToPickup with stub geo: map behind the card, heading '
        'marker, pickup objective chip with along-leg distance',
        (tester) async {
      await pumpRunner(
        tester,
        _GeoRepo(geo: stubGeo(), position: positionAt(spawn, heading: 90)),
      );

      // The canvas is up and the car marker (heading chevron) renders.
      final map = tester.widget<HopMap>(find.byType(HopMap));
      expect(find.byKey(HopMap.carMarkerKey), findsOneWidget);
      expect(map.carPosition, hop(spawn));
      expect(map.carHeading, 90);
      expect(map.cameraIntent, FollowPoint(hop(spawn)),
          reason: 'the chase camera follows the driver');
      expect(map.pins.single.point, hop(pickup));
      expect(map.pins.single.role, HopMapPinRole.objective);
      expect(map.track!.points.first, hop(spawn),
          reason: 'pre-start the track is the approach leg');

      // The objective chip: pickup-flavored label + the remaining distance.
      // 'Pickup' appears twice — the stage spine dot AND the chip.
      expect(find.text('Pickup'), findsNWidgets(2),
          reason: 'stage spine + objective chip both read Pickup');
      expect(find.text('Drop-off'), findsNothing);
      expect(find.text(chipDistance(approachLeg)), findsOneWidget);

      // The runner card is still THE card, above the canvas.
      expect(find.byKey(const ValueKey('trip-runner-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('driving the runner to started flips chip and pin together',
        (tester) async {
      final runner = await pumpRunner(
        tester,
        _GeoRepo(geo: stubGeo(), position: positionAt(pickup)),
      );
      runner.drive(TripPhase.arrivedAtPickup);
      await settleMorph(tester);

      // Still the pickup objective while waiting at the kerb.
      expect(find.text('Drop-off'), findsNothing);
      var map = tester.widget<HopMap>(find.byType(HopMap));
      expect(map.pins.single.point, hop(pickup));

      // Slide-Start happened: the runner reports started.
      runner.drive(TripPhase.inTrip);
      await settleMorph(tester);

      // Chip label, objective pin, and track all flipped to the trip leg.
      expect(find.text('Drop-off'), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget,
          reason: 'only the stage spine says Pickup once the chip flips');
      expect(find.text(chipDistance(routeLeg)), findsOneWidget,
          reason: 'the distance re-measures along the pickup→destination leg');
      map = tester.widget<HopMap>(find.byType(HopMap));
      expect(map.pins.single.point, hop(dropoff));
      expect(map.track!.points.last, hop(dropoff));
      expect(map.cameraIntent, FollowPoint(hop(pickup)),
          reason: 'the chase camera keeps following the car through the flip');
      expect(tester.takeException(), isNull);
    });

    testWidgets('both seams null: no HopMap in the runner tree (live mode)',
        (tester) async {
      await pumpRunner(tester, _GeoRepo());

      expect(find.byType(HopMap), findsNothing,
          reason: 'MapPhase.hidden must render NOTHING — the canvas-less '
              'Phase 3 runner layout is the live-mode contract');
      // The runner itself reads exactly as before the map landed.
      expect(find.text('Head to pickup'), findsOneWidget);
      expect(find.byKey(const ValueKey('trip-runner-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('light theme pumps clean (dark is the suite default)',
        (tester) async {
      await pumpRunner(
        tester,
        _GeoRepo(geo: stubGeo(), position: positionAt(spawn)),
        theme: HoppinTheme.driverLight(),
      );

      expect(find.byType(HopMap), findsOneWidget);
      expect(find.byKey(HopMap.carMarkerKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('offer takeover context inset', () {
    const TripRiderContext sophie = (
      name: 'Sophie Bell',
      photoUrl: null,
      rating: 4.8,
      ratingCount: 12,
      recentComments: ['Always on time'],
      pickupLabel: 'Wolverhampton Rail Station',
      pickupEtaSeconds: 120,
    );

    final offer = RideOffer(
      offerId: 'offer-1',
      rideId: 'ride-1',
      pickupLat: 52.5875,
      pickupLng: -2.1288,
      dropoffLat: 52.5906,
      dropoffLng: -2.0929,
      fare: 6.39,
      estimatedMiles: 1.7,
      expiresAt: clock.now().add(const Duration(seconds: 45)),
      offeredAt: clock.now(),
    );

    const driverSpawn = HopGeoPoint(52.5903, -2.1306);
    final pickupPoint = HopGeoPoint(offer.pickupLat, offer.pickupLng);

    OfferTakeoverState fixture({HopGeoPoint? driver}) => OfferTakeoverState(
          offer: offer,
          presentedAt: clock.now(),
          deadline: clock.now().add(const Duration(seconds: 45)),
          driverContextPosition: driver,
        );

    Future<_StubTakeover> pumpTakeover(
      WidgetTester tester,
      OfferTakeoverState state, {
      ThemeData? theme,
    }) async {
      final stub = _StubTakeover(offer, state);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          offerTakeoverInteractorProvider.overrideWith2((offer) => stub),
          tripRiderContextProvider.overrideWith((ref, _) async => sophie),
          mapTileProvider.overrideWithValue(NoNetworkTileProvider()),
        ],
        child: MaterialApp(
          theme: theme ?? HoppinTheme.driverDark(),
          home: OfferTakeoverView(offer: offer),
        ),
      ));
      // Resolve the rider context + play the entrance stagger out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return stub;
    }

    testWidgets('renders fully inert: a drag changes nothing, dispatches '
        'nothing, and no gesture path exists', (tester) async {
      final stub = await pumpTakeover(tester, fixture(driver: driverSpawn));

      // Structural inertness: interactive false → HopMap's own IgnorePointer
      // absorbs every hit before any gesture handler can exist.
      final map = tester.widget<HopMap>(find.byType(HopMap));
      expect(map.interactive, isFalse);
      final ignore = tester.widget<IgnorePointer>(find
          .descendant(
            of: find.byType(HopMap),
            matching: find.byType(IgnorePointer),
          )
          .first);
      expect(ignore.ignoring, isTrue);

      // Static context framing: one fit of driver + pickup, car marker up.
      expect(map.cameraIntent, FitPoints([driverSpawn, pickupPoint]));
      expect(map.carPosition, driverSpawn);
      expect(find.byKey(HopMap.carMarkerKey), findsOneWidget);

      // A drag across the inset: no accept, no decline, no exception — and
      // the card's tap-anywhere accept does not misfire from a pan.
      await tester.drag(
        find.byType(HopMap),
        const Offset(80, 0),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(stub.acceptCalls, 0);
      expect(stub.declineCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('payout hero stays THE largest text with the inset present',
        (tester) async {
      await pumpTakeover(tester, fixture(driver: driverSpawn));

      final heroFinder = find.text('£6.39');
      expect(heroFinder, findsOneWidget);
      final hero = tester.widget<Text>(heroFinder);
      final heroSize = hero.style?.fontSize;
      expect(heroSize, isNotNull);

      // The squint test, automated — the map adds chrome (attribution) but
      // nothing may challenge the money.
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        if (identical(text, hero)) continue;
        final size = text.style?.fontSize ?? 14;
        expect(size, lessThan(heroSize!),
            reason: '"${text.data}" must render smaller than the hero payout');
      }

      // The inset sits BELOW the money — supporting context, never rival.
      expect(
        tester.getTopLeft(find.byType(HopMap)).dy,
        greaterThan(tester.getBottomLeft(heroFinder).dy),
        reason: 'the map inset must sit below the payout hero',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('null driver position degrades to a pickup-pin-only frame',
        (tester) async {
      await pumpTakeover(tester, fixture());

      final map = tester.widget<HopMap>(find.byType(HopMap));
      expect(map.carPosition, isNull);
      expect(find.byKey(HopMap.carMarkerKey), findsNothing,
          reason: 'no seam answer → no car marker, never a crash');
      expect(map.pins.single.point, pickupPoint);
      expect(map.pins.single.role, HopMapPinRole.pickup);
      expect(map.cameraIntent, FitPoints([pickupPoint]));
      expect(find.text('£6.39'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('light theme pumps clean (dark is the suite default)',
        (tester) async {
      await pumpTakeover(
        tester,
        fixture(driver: driverSpawn),
        theme: HoppinTheme.driverLight(),
      );

      expect(find.byType(HopMap), findsOneWidget);
      expect(find.text('£6.39'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// The same haversine the interactor hand-rolls (the sanctioned pure-Dart
/// exception; no latlong2 in apps) — expectation math for the chip.
double _haversineMeters(HopGeoPoint a, HopGeoPoint b) {
  const earthRadiusMeters = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final sinLat = math.sin(dLat / 2);
  final sinLng = math.sin(dLng / 2);
  final h = sinLat * sinLat +
      math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * sinLng * sinLng;
  return 2 * earthRadiusMeters * math.asin(math.sqrt(h));
}

/// Drivable trip-runner stub: build() returns the initial heading state
/// (no timers, no repo reads) and [drive] walks the phase forward — the
/// objective input the REAL map interactor listens to.
class _StubRunner extends TripRunnerInteractor {
  _StubRunner() : super('ride-1');

  @override
  TripRunnerState build() => const TripRunnerState(rideId: 'ride-1');

  void drive(TripPhase phase) => state = state.copyWith(phase: phase);
}

/// Fixture-holding takeover stub: build() returns the fixed state without
/// arming timers, playing the chime, or fetching context; the intent
/// methods record instead of act.
class _StubTakeover extends OfferTakeoverInteractor {
  _StubTakeover(super.offer, this.fixture);

  final OfferTakeoverState fixture;
  int acceptCalls = 0;
  int declineCalls = 0;

  @override
  OfferTakeoverState build() => fixture;

  @override
  Future<void> accept() async {
    acceptCalls++;
  }

  @override
  Future<void> decline() async {
    declineCalls++;
  }
}

/// Stubbed geo seams: nullable position/geometry answered instantly — the
/// degradation rungs under view test.
class _GeoRepo implements RidesRepository {
  _GeoRepo({this.geo, this.position});

  final RideGeo? geo;
  final DriverPosition? position;

  @override
  Future<DriverPosition?> driverPosition(String rideId) =>
      Future.value(position);

  @override
  Future<RideGeo?> rideGeo(String rideId) => Future.value(geo);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
