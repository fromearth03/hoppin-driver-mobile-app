import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/api/api_exception.dart';
import 'package:hoppin_driver/core/money.dart';
import 'package:hoppin_driver/core/result.dart';
import 'package:hoppin_driver/features/home/data/driver_status_repository.dart';
import 'package:hoppin_driver/features/home/data/models/driver_status.dart';
import 'package:hoppin_driver/features/home/data/models/pending_offer.dart';
import 'package:hoppin_driver/features/home/data/offer_repository.dart';
import 'package:hoppin_driver/features/home/logic/home_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockStatusRepo extends Mock implements DriverStatusRepository {}

class MockOfferRepo extends Mock implements OfferRepository {}

DriverStatus buildStatus({
  Presence presence = Presence.offline,
  String? blocked,
  String? activeRide,
  DateTime? lastLocationAt,
}) =>
    DriverStatus(
      presence: presence,
      staleAfterSeconds: 90,
      dispatchable: blocked == null && presence == Presence.online,
      blockedReason: blocked,
      activeRideId: activeRide,
      lastLocationAt: lastLocationAt,
    );

PendingOffer buildOffer({String id = 'o1'}) => PendingOffer(
      id: id,
      rideId: 'r1',
      fare: const Pence(2015),
      pickupLabel: 'City Centre',
      dropoffLabel: 'Station',
      expiresInSec: 60,
      receivedAt: DateTime.now(),
    );

void main() {
  late MockStatusRepo status;
  late MockOfferRepo offers;

  setUp(() {
    status = MockStatusRepo();
    offers = MockOfferRepo();
    when(() => offers.offers()).thenAnswer((_) async => const Ok([]));
    when(() => status.goOffline()).thenAnswer((_) async => const Ok(null));
  });

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      driverStatusRepositoryProvider.overrideWithValue(status),
      offerRepositoryProvider.overrideWithValue(offers),
      pollIntervalProvider.overrideWithValue(const Duration(milliseconds: 20)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('stale presence', () {
    test('a stale driver is still on shift, so the toggle reads online',
        () async {
      when(() => status.status())
          .thenAnswer((_) async => Ok(buildStatus(presence: Presence.stale)));

      final c = container();
      final state = await c.read(homeControllerProvider.future);

      // Stale means "online but GPS has gone quiet" — not offline. Showing
      // the toggle off would tell the driver they are off shift when the
      // dispatcher still has them on.
      expect(state.isOnline, isTrue);
    });

    test('toggling from stale goes offline rather than re-sending online',
        () async {
      when(() => status.status())
          .thenAnswer((_) async => Ok(buildStatus(presence: Presence.stale)));

      final c = container();
      await c.read(homeControllerProvider.future);
      await c.read(homeControllerProvider.notifier).toggleOnline();

      verify(() => status.goOffline()).called(1);
      verifyNever(() => status.goOnline());
    });
  });

  group('going offline', () {
    test('a failed go-offline keeps the driver on shift and reports the error',
        () async {
      when(() => status.status())
          .thenAnswer((_) async => Ok(buildStatus(presence: Presence.online)));
      when(() => status.goOffline())
          .thenAnswer((_) async => Err(ApiException('INTERNAL', '', 0)));

      final c = container();
      await c.read(homeControllerProvider.future);
      await c.read(homeControllerProvider.notifier).toggleOnline();

      final state = c.read(homeControllerProvider).value!;
      // The server still has them online and dispatchable. Flipping the
      // toggle off here would strand a driver taking jobs they cannot see.
      expect(state.isOnline, isTrue);
      expect(state.error, isNotNull);
    });
  });

  group('state written after an await', () {
    test('going online does not discard an offer that arrived mid-request',
        () async {
      when(() => status.status())
          .thenAnswer((_) async => Ok(buildStatus(presence: Presence.offline)));
      when(() => status.goOnline()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return Ok(buildStatus(presence: Presence.online));
      });
      when(() => offers.offers()).thenAnswer((_) async => Ok([buildOffer()]));

      final c = container();
      await c.read(homeControllerProvider.future);
      final controller = c.read(homeControllerProvider.notifier);

      final going = controller.toggleOnline();
      await controller.onPushWake(); // lands while goOnline is in flight
      await going;

      expect(c.read(homeControllerProvider).value!.offer, isNotNull);
      controller.stopPolling();
    });

    test('a blocked status keeps the last known location', () async {
      final seenAt = DateTime.utc(2026, 8, 30, 10);
      when(() => status.status()).thenAnswer((_) async =>
          Ok(buildStatus(presence: Presence.online, lastLocationAt: seenAt)));
      when(() => status.goOnline()).thenAnswer(
          (_) async => Err(ApiException('PAYOUT_NOT_READY', '', 403)));

      final c = container();
      await c.read(homeControllerProvider.future);
      await c.read(homeControllerProvider.notifier).toggleOnline();

      expect(c.read(homeControllerProvider).value!.status!.lastLocationAt,
          seenAt);
    });
  });

  group('accepting an offer', () {
    test('stops polling even when the accept fails', () async {
      when(() => status.status())
          .thenAnswer((_) async => Ok(buildStatus(presence: Presence.online)));
      when(() => offers.offers()).thenAnswer((_) async => Ok([buildOffer()]));
      when(() => offers.accept(any(), rideId: any(named: 'rideId')))
          .thenAnswer((_) async => Err(ApiException('OFFER_EXPIRED', '', 409)));

      final c = container();
      await c.read(homeControllerProvider.future);
      final controller = c.read(homeControllerProvider.notifier);
      await controller.onPushWake();
      controller.startPolling();

      await controller.acceptOffer();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // A lapsed offer must not be re-rendered by the very next tick.
      expect(c.read(homeControllerProvider).value!.offer, isNull);
      controller.stopPolling();
    });
  });

  group('disposal', () {
    test('a tick resolving after disposal does not throw', () async {
      when(() => status.status())
          .thenAnswer((_) async => Ok(buildStatus(presence: Presence.online)));
      when(() => offers.offers()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return Ok([buildOffer()]);
      });

      final c = ProviderContainer(overrides: [
        driverStatusRepositoryProvider.overrideWithValue(status),
        offerRepositoryProvider.overrideWithValue(offers),
      ]);
      await c.read(homeControllerProvider.future);
      final controller = c.read(homeControllerProvider.notifier);

      final wake = controller.onPushWake();
      c.dispose();

      await expectLater(wake, completes);
    });
  });
}
