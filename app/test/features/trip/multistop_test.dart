import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/trip/data/cancel_reason_repository.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/ride_stop.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:hoppin_driver/features/trip/logic/trip_controller.dart';
import 'package:hoppin_driver/features/trip/ui/widgets/stops_card.dart';
import 'package:mocktail/mocktail.dart';

class MockTripRepo extends Mock implements TripRepository {}

class MockReasonRepo extends Mock implements CancelReasonRepository {}

/// The payload `GET /rides/:id/stops` returns, field for field as
/// `RideStopRow` tags them. The doc's worked example: 30 + 90 + 20.
Map<String, dynamic> stopsPayload({
  String? arrivedAt,
  String? departedAt,
  int waitingPence = 0,
}) =>
    {
      'multi_stop': true,
      'stops': [
        {
          'seq': 0,
          'kind': 'stop',
          'label': 'Tesco',
          'from_lat': 52.586,
          'from_lng': -2.128,
          'to_lat': 52.580,
          'to_lng': -2.120,
          'distance_meters': 1400,
          'duration_seconds': 300,
          'fare_pence': 3000,
          'waiting_seconds': 240,
          'waiting_pence': waitingPence,
          'arrived_at': arrivedAt,
          'departed_at': departedAt,
          'added_mid_trip': false,
        },
        {
          'seq': 1,
          'kind': 'stop',
          'label': "Mum's",
          'from_lat': 52.580,
          'from_lng': -2.120,
          'to_lat': 52.578,
          'to_lng': -2.101,
          'distance_meters': 6100,
          'duration_seconds': 720,
          'fare_pence': 9000,
          'waiting_seconds': 0,
          'waiting_pence': 0,
          'arrived_at': null,
          'departed_at': null,
          'added_mid_trip': true,
        },
        {
          'seq': 2,
          'kind': 'dropoff',
          'label': 'Dropoff',
          'from_lat': 52.578,
          'from_lng': -2.101,
          'to_lat': 52.593,
          'to_lng': -2.110,
          'distance_meters': 1800,
          'duration_seconds': 360,
          'fare_pence': 2000,
          'waiting_seconds': 0,
          'waiting_pence': 0,
          'arrived_at': null,
          'departed_at': null,
          'added_mid_trip': false,
        },
      ],
      'legs_total_pence': 14000,
      'waiting_total_pence': waitingPence,
      'total_pence': 14000 + waitingPence,
    };

Ride buildRide(String status) => Ride(
      id: 'r1',
      status: status,
      geo: const RideGeo(
        pickup: GeoPoint(lat: 52.586, lng: -2.128),
        dropoff: GeoPoint(lat: 52.593, lng: -2.110, label: 'Station'),
      ),
    );

void main() {
  group('RideStops parsing', () {
    test('reads the per-leg breakdown the service sends', () {
      final stops = RideStops.fromJson(stopsPayload());

      expect(stops.multiStop, isTrue);
      expect(stops.stops.length, 3);
      expect(stops.legsTotal, const Pence(14000));
      expect(stops.total, const Pence(14000));
      // Two intermediate stops; the dropoff is a leg, not a stop.
      expect(stops.stopCount, 2);
      expect(stops.stops.first.fare, const Pence(3000));
      expect(stops.stops.first.label, 'Tesco');
      expect(stops.stops.last.isDropoff, isTrue);
    });

    test('a single-leg ride is not multi-stop', () {
      final stops = RideStops.fromJson({
        'multi_stop': false,
        'stops': <dynamic>[],
        'legs_total_pence': 0,
        'waiting_total_pence': 0,
        'total_pence': 0,
      });

      expect(stops.multiStop, isFalse);
      expect(stops.stopCount, 0);
      expect(stops.nextStop, isNull);
    });

    test('waiting is added to the legs total, not folded into a leg', () {
      final stops = RideStops.fromJson(stopsPayload(waitingPence: 25));

      expect(stops.legsTotal, const Pence(14000));
      expect(stops.waitingTotal, const Pence(25));
      expect(stops.total, const Pence(14025));
    });

    test('orders by seq even if the payload arrives shuffled', () {
      final payload = stopsPayload();
      payload['stops'] = (payload['stops'] as List).reversed.toList();

      final stops = RideStops.fromJson(payload);

      expect(stops.stops.map((s) => s.seq), [0, 1, 2]);
    });

    test('the dropoff leg never offers waiting', () {
      final stops = RideStops.fromJson(stopsPayload());
      final dropoff = stops.stops.firstWhere((s) => s.isDropoff);

      // The repository only stamps rows with kind = 'stop', so an
      // arrive/depart button here would call an endpoint that does nothing.
      expect(dropoff.canWait, isFalse);
    });

    test('nextStop is the first stop not yet departed', () {
      final none = RideStops.fromJson(stopsPayload());
      expect(none.nextStop?.seq, 0);

      final firstDone = RideStops.fromJson(stopsPayload(
        arrivedAt: '2026-08-31 10:00:00+00',
        departedAt: '2026-08-31 10:05:00+00',
      ));
      expect(firstDone.nextStop?.seq, 1);
    });

    test('reads Postgres timestamps, which use a space not a T', () {
      final stops = RideStops.fromJson(
          stopsPayload(arrivedAt: '2026-08-31 10:00:00+00'));

      expect(stops.stops.first.arrivedAt, isNotNull);
      expect(stops.stops.first.isWaiting, isTrue);
      expect(stops.waitingAt?.seq, 0);
    });

    test('a stop added mid-trip is flagged as such', () {
      final stops = RideStops.fromJson(stopsPayload());

      expect(stops.stops[1].addedMidTrip, isTrue);
      expect(stops.stops[0].addedMidTrip, isFalse);
    });
  });

  group('RideGeo waypoints', () {
    test('reads the intermediate stops the payload carries', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'in_progress',
        'geo': {
          'pickup': {'lat': 52.586, 'lng': -2.128},
          'dropoff': {'lat': 52.593, 'lng': -2.110},
          'waypoints': [
            {'lat': 52.580, 'lng': -2.120, 'label': 'Tesco'},
          ],
        },
      });

      expect(ride.geo.isMultiStop, isTrue);
      expect(ride.geo.waypoints.single.label, 'Tesco');
      // Pickup, the stop, then dropoff — the order the map frames.
      expect(ride.geo.allPoints.length, 3);
    });

    test('an ordinary ride has no waypoints', () {
      final ride = Ride.fromJson({
        'id': 'r1',
        'status': 'accepted',
        'geo': {
          'pickup': {'lat': 1.0, 'lng': 2.0},
          'dropoff': {'lat': 3.0, 'lng': 4.0},
        },
      });

      expect(ride.geo.isMultiStop, isFalse);
      expect(ride.geo.allPoints.length, 2);
    });
  });

  group('TripController stop actions', () {
    late MockTripRepo repo;
    late MockReasonRepo reasons;

    ProviderContainer container() {
      final c = ProviderContainer(overrides: [
        tripRepositoryProvider.overrideWithValue(repo),
        cancelReasonRepositoryProvider.overrideWithValue(reasons),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      repo = MockTripRepo();
      reasons = MockReasonRepo();
      when(() => repo.ride(any()))
          .thenAnswer((_) async => Ok(buildRide('in_progress')));
      when(() => repo.riderContext(any())).thenAnswer(
          (_) async => Err(ApiException('NOT_FOUND', 'none', 404)));
      when(() => reasons.forDriver()).thenAnswer((_) async => const Ok([]));
      when(() => repo.stops(any()))
          .thenAnswer((_) async => Ok(RideStops.fromJson(stopsPayload())));
    });

    test('loads the breakdown alongside the ride', () async {
      final state = await container().read(tripControllerProvider('r1').future);

      expect(state.stops.multiStop, isTrue);
      expect(state.stops.stopCount, 2);
    });

    test('a failed breakdown degrades to single-leg, not to a broken screen',
        () async {
      when(() => repo.stops(any())).thenAnswer(
          (_) async => Err(ApiException('BOOM', 'stops down', 500)));

      final state = await container().read(tripControllerProvider('r1').future);

      // The trip itself still loads, with its Arrive/Start/Finish actions.
      expect(state.ride, isNotNull);
      expect(state.stops.multiStop, isFalse);
    });

    test('arriving re-reads the breakdown rather than patching it locally',
        () async {
      final c = container();
      await c.read(tripControllerProvider('r1').future);
      when(() => repo.arriveAtStop('r1', 0))
          .thenAnswer((_) async => const Ok(null));
      // The server stamps arrived_at with its own now(); the app must take
      // that reading rather than starting a clock on the handset.
      when(() => repo.stops(any())).thenAnswer((_) async =>
          Ok(RideStops.fromJson(
              stopsPayload(arrivedAt: '2026-08-31 10:00:00+00'))));

      await c.read(tripControllerProvider('r1').notifier).arriveAtStop(0);

      final state = c.read(tripControllerProvider('r1')).value!;
      expect(state.stops.waitingAt?.seq, 0);
      expect(state.isBusy, isFalse);
      verify(() => repo.arriveAtStop('r1', 0)).called(1);
    });

    test('departing returns the waiting charge the server applied', () async {
      final c = container();
      await c.read(tripControllerProvider('r1').future);
      when(() => repo.departStop('r1', 0))
          .thenAnswer((_) async => const Ok(Pence(25)));

      final result =
          await c.read(tripControllerProvider('r1').notifier).departStop(0);

      expect(result.valueOrNull, const Pence(25));
    });

    test('a failed depart still re-reads, and surfaces the error', () async {
      final c = container();
      await c.read(tripControllerProvider('r1').future);
      when(() => repo.departStop('r1', 0)).thenAnswer(
          (_) async => Err(ApiException('BOOM', 'depart failed', 500)));

      await c.read(tripControllerProvider('r1').notifier).departStop(0);

      final state = c.read(tripControllerProvider('r1')).value!;
      expect(state.error?.code, 'BOOM');
      expect(state.isBusy, isFalse);
      // Two reads: the initial load, and the settle after the failure —
      // the row may have moved even though the call reported failure.
      verify(() => repo.stops(any())).called(greaterThanOrEqualTo(2));
    });

    test('adding a stop returns the re-priced total', () async {
      final c = container();
      await c.read(tripControllerProvider('r1').future);
      when(() => repo.addStop(any(),
              lat: any(named: 'lat'),
              lng: any(named: 'lng'),
              label: any(named: 'label')))
          .thenAnswer((_) async =>
              const Ok(AddedStop(total: Pence(16500), stopsCount: 3)));

      final result = await c
          .read(tripControllerProvider('r1').notifier)
          .addStop(lat: 52.577, lng: -2.099, label: 'Pharmacy');

      expect(result.valueOrNull?.total, const Pence(16500));
      expect(result.valueOrNull?.stopsCount, 3);
    });

    test('RIDE_CLOSED on a finished ride surfaces as an error', () async {
      final c = container();
      await c.read(tripControllerProvider('r1').future);
      when(() => repo.addStop(any(),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          label: any(named: 'label'))).thenAnswer((_) async =>
          Err(ApiException('RIDE_CLOSED', 'ride already finished', 409)));

      final result = await c
          .read(tripControllerProvider('r1').notifier)
          .addStop(lat: 1, lng: 2, label: 'Too late');

      expect(result.errorOrNull?.code, 'RIDE_CLOSED');
      expect(c.read(tripControllerProvider('r1')).value!.error?.code,
          'RIDE_CLOSED');
    });
  });

  group('StopsCard', () {
    Widget host(RideStops stops, {void Function(RideStop)? onArrive}) =>
        MaterialApp(
          home: Scaffold(
            body: StopsCard(stops: stops, onArrive: onArrive),
          ),
        );

    testWidgets('draws nothing on a single-leg ride', (tester) async {
      await tester.pumpWidget(host(RideStops.empty));

      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.textContaining('stop'), findsNothing);
    });

    testWidgets('lists every leg with its own fare', (tester) async {
      await tester.pumpWidget(host(RideStops.fromJson(stopsPayload())));

      expect(find.text('2 stops on this trip'), findsOneWidget);
      expect(find.text('Tesco'), findsOneWidget);
      expect(find.text('£30.00'), findsOneWidget);
      expect(find.text('£90.00'), findsOneWidget);
      expect(find.text('£20.00'), findsOneWidget);
      // The grand total, which is what the cuts come off once.
      expect(find.text('£140.00'), findsOneWidget);
    });

    testWidgets('says the fees come off the total, not each leg',
        (tester) async {
      await tester.pumpWidget(host(RideStops.fromJson(stopsPayload())));

      expect(find.textContaining('once, not per leg'), findsOneWidget);
    });

    testWidgets('offers arrive on a stop but never on the dropoff',
        (tester) async {
      await tester.pumpWidget(
          host(RideStops.fromJson(stopsPayload()), onArrive: (_) {}));

      expect(find.byKey(const Key('stop_action_0')), findsOneWidget);
      expect(find.byKey(const Key('stop_action_1')), findsOneWidget);
      // seq 2 is the dropoff.
      expect(find.byKey(const Key('stop_action_2')), findsNothing);
    });

    testWidgets('switches to Depart once the driver has arrived',
        (tester) async {
      await tester.pumpWidget(host(
        RideStops.fromJson(
            stopsPayload(arrivedAt: '2026-08-31 10:00:00+00')),
        onArrive: (_) {},
      ));

      expect(find.text('Depart'), findsOneWidget);
      expect(find.text('Arrived at stop'), findsOneWidget); // the second stop
    });

    testWidgets('shows the waiting charged once it is non-zero',
        (tester) async {
      await tester.pumpWidget(host(
        RideStops.fromJson(stopsPayload(
          arrivedAt: '2026-08-31 10:00:00+00',
          departedAt: '2026-08-31 10:05:00+00',
          waitingPence: 25,
        )),
        // The "Departed" state lives in the action row, which only exists
        // once the trip is under way and the callbacks are wired.
        onArrive: (_) {},
      ));

      expect(find.text('Waiting so far'), findsOneWidget);
      expect(find.text('£0.25'), findsWidgets);
      expect(find.text('Departed'), findsOneWidget);
    });

    testWidgets('marks a stop that was added mid-trip', (tester) async {
      await tester.pumpWidget(host(RideStops.fromJson(stopsPayload())));

      expect(find.textContaining('added mid-trip'), findsOneWidget);
    });

    testWidgets('offers no stop actions before the trip has started',
        (tester) async {
      // onArrive/onDepart null: the driver cannot serve a stop with nobody
      // aboard, so the buttons are absent rather than merely disabled.
      await tester.pumpWidget(host(RideStops.fromJson(stopsPayload())));

      expect(find.byKey(const Key('stop_action_0')), findsNothing);
    });
  });
}
