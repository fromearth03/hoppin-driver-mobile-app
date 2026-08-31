import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/trip/data/models/ride.dart';
import 'package:hoppin_driver/features/trip/data/models/ride_stop.dart';
import 'package:hoppin_driver/features/trip/data/trip_repository.dart';
import 'package:hoppin_driver/features/trip/logic/trip_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockTripRepo extends Mock implements TripRepository {}

/// `GET /rides/:id` carries no rider block at all — that data lives only on
/// `/rides/:id/rider-context`. The repository already fetched it and nothing
/// wired it in, so the trip screen never showed who the driver was
/// collecting.
Ride rideOnly(String status) => Ride(
      id: 'r1',
      status: status,
      ref: 'R-1042',
      geo: const RideGeo(
        pickup: GeoPoint(lat: 1, lng: 2, label: 'City Centre'),
        dropoff: GeoPoint(lat: 3, lng: 4, label: 'Station'),
      ),
    );

/// The context exactly as the service builds it. `name` is first-name-only
/// by design, and the rating is null until the rider has actually been rated.
Map<String, dynamic> liveContext() => {
      'name': 'Alex',
      'photo_url': 'https://cdn/alex.jpg',
      'rating': 4.8,
      'rating_count': 12,
      'recent_comments': <String>[],
      'pickup_label': 'City Centre',
      'pickup_eta_seconds': 240,
    };

void main() {
  late MockTripRepo repo;

  setUp(() {
    repo = MockTripRepo();
    when(() => repo.stops(any()))
        .thenAnswer((_) async => const Ok(RideStops.empty));
    when(() => repo.waitingPolicy(any()))
        .thenAnswer((_) async => Err(ApiException('NOT_FOUND', '', 404)));
  });

  ProviderContainer container() {
    final c = ProviderContainer(
        overrides: [tripRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    return c;
  }

  test('the rider is loaded from rider-context, not from the ride', () async {
    when(() => repo.ride(any()))
        .thenAnswer((_) async => Ok(rideOnly('accepted')));
    when(() => repo.riderContext(any()))
        .thenAnswer((_) async => Ok(liveContext()));

    final state = await container().read(tripControllerProvider('r1').future);

    expect(state.ride!.rider, isNotNull);
    expect(state.ride!.rider!.fullName, 'Alex');
    expect(state.ride!.rider!.rating, 4.8);
    expect(state.ride!.rider!.ratingCount, 12);
  });

  test('a trip still loads when the rider context fails', () async {
    when(() => repo.ride(any()))
        .thenAnswer((_) async => Ok(rideOnly('accepted')));
    when(() => repo.riderContext(any()))
        .thenAnswer((_) async => Err(ApiException('INTERNAL', 'boom', 500)));

    final state = await container().read(tripControllerProvider('r1').future);

    // Losing the rider's name must never cost the driver the trip screen and
    // its Arrive/Start/Complete actions.
    expect(state.ride, isNotNull);
    expect(state.ride!.rider, isNull);
    expect(state.error, isNull);
  });

  test('a finished ride never asks for rider context', () async {
    when(() => repo.ride(any()))
        .thenAnswer((_) async => Ok(rideOnly('completed')));

    final state = await container().read(tripControllerProvider('r1').future);

    // The service 409s RIDE_NOT_ACTIVE once a ride completes or cancels, so
    // asking is a guaranteed error the driver would see for no reason.
    expect(state.ride, isNotNull);
    verifyNever(() => repo.riderContext(any()));
  });
}
