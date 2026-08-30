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

class _MockStatusRepo extends Mock implements DriverStatusRepository {}

class _MockOfferRepo extends Mock implements OfferRepository {}

DriverStatus buildStatus({
  Presence presence = Presence.offline,
  String? blocked,
  List<String> docs = const [],
  String? activeRide,
}) =>
    DriverStatus(
      presence: presence,
      staleAfterSeconds: 90,
      dispatchable: blocked == null && presence == Presence.online,
      blockedReason: blocked,
      blockingDocumentTypes: docs,
      activeRideId: activeRide,
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
  late _MockStatusRepo status;
  late _MockOfferRepo offers;

  setUp(() {
    status = _MockStatusRepo();
    offers = _MockOfferRepo();
    when(() => offers.offers()).thenAnswer((_) async => const Ok([]));
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

  test('loads status on build', () async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(buildStatus(presence: Presence.offline)));

    final c = container();
    final state = await c.read(homeControllerProvider.future);

    expect(state.status!.presence, Presence.offline);
    expect(state.offer, isNull);
  });

  test('going online stores the returned status', () async {
    when(() => status.status()).thenAnswer((_) async => Ok(buildStatus()));
    when(() => status.goOnline())
        .thenAnswer((_) async => Ok(buildStatus(presence: Presence.online)));

    final c = container();
    await c.read(homeControllerProvider.future);
    await c.read(homeControllerProvider.notifier).toggleOnline();

    expect(
        c.read(homeControllerProvider).value!.status!.presence, Presence.online);
    c.read(homeControllerProvider.notifier).stopPolling();
  });

  test('a NOT_ELIGIBLE refusal becomes a blocked status, not an error toast',
      () async {
    when(() => status.status()).thenAnswer((_) async => Ok(buildStatus()));
    when(() => status.goOnline())
        .thenAnswer((_) async => Err(ApiException('NOT_ELIGIBLE', 'blocked', 403,
                fields: {
                  'reason': 'DOCS_EXPIRED',
                  'blocking_document_types': ['vehicle_insurance'],
                })));

    final c = container();
    await c.read(homeControllerProvider.future);
    await c.read(homeControllerProvider.notifier).toggleOnline();

    final s = c.read(homeControllerProvider).value!.status!;
    expect(s.isBlocked, isTrue);
    expect(s.blockedReason, 'DOCS_EXPIRED');
    expect(s.blockingDocumentTypes, ['vehicle_insurance']);
  });

  test('PAYOUT_NOT_READY also lands as a blocked reason', () async {
    when(() => status.status()).thenAnswer((_) async => Ok(buildStatus()));
    when(() => status.goOnline()).thenAnswer(
        (_) async => Err(ApiException('PAYOUT_NOT_READY', '', 403)));

    final c = container();
    await c.read(homeControllerProvider.future);
    await c.read(homeControllerProvider.notifier).toggleOnline();

    expect(c.read(homeControllerProvider).value!.status!.blockedReason,
        'PAYOUT_NOT_READY');
  });

  test('polls for offers while online', () async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(buildStatus(presence: Presence.online)));
    when(() => offers.offers()).thenAnswer((_) async => Ok([buildOffer()]));

    final c = container();
    await c.read(homeControllerProvider.future);
    c.read(homeControllerProvider.notifier).startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(c.read(homeControllerProvider).value!.offer, isNotNull);
    c.read(homeControllerProvider.notifier).stopPolling();
  });

  test('does not poll while offline', () async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(buildStatus(presence: Presence.offline)));

    final c = container();
    await c.read(homeControllerProvider.future);
    c.read(homeControllerProvider.notifier).startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    verifyNever(() => offers.offers());
    c.read(homeControllerProvider.notifier).stopPolling();
  });

  test('does not poll while on a trip', () async {
    when(() => status.status()).thenAnswer((_) async =>
        Ok(buildStatus(presence: Presence.online, activeRide: 'ride-1')));

    final c = container();
    await c.read(homeControllerProvider.future);
    c.read(homeControllerProvider.notifier).startPolling();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    verifyNever(() => offers.offers());
    c.read(homeControllerProvider.notifier).stopPolling();
  });

  test('a push wake fetches immediately rather than trusting the payload',
      () async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(buildStatus(presence: Presence.online)));
    when(() => offers.offers()).thenAnswer((_) async => Ok([buildOffer()]));

    final c = container();
    await c.read(homeControllerProvider.future);
    await c.read(homeControllerProvider.notifier).onPushWake();

    verify(() => offers.offers()).called(greaterThanOrEqualTo(1));
    expect(c.read(homeControllerProvider).value!.offer!.id, 'o1');
  });

  test('accepting clears the offer and reports the ride id', () async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(buildStatus(presence: Presence.online)));
    when(() => offers.offers()).thenAnswer((_) async => Ok([buildOffer()]));
    when(() => offers.accept('o1')).thenAnswer((_) async => const Ok('ride-9'));

    final c = container();
    await c.read(homeControllerProvider.future);
    await c.read(homeControllerProvider.notifier).onPushWake();

    final r = await c.read(homeControllerProvider.notifier).acceptOffer();

    expect(r.valueOrNull, 'ride-9');
    expect(c.read(homeControllerProvider).value!.offer, isNull);
  });

  test('an expired offer clears rather than sticking on screen', () async {
    when(() => status.status())
        .thenAnswer((_) async => Ok(buildStatus(presence: Presence.online)));
    when(() => offers.offers()).thenAnswer((_) async => Ok([buildOffer()]));
    when(() => offers.accept(any()))
        .thenAnswer((_) async => Err(ApiException('OFFER_EXPIRED', '', 409)));

    final c = container();
    await c.read(homeControllerProvider.future);
    await c.read(homeControllerProvider.notifier).onPushWake();
    final r = await c.read(homeControllerProvider.notifier).acceptOffer();

    expect(r.errorOrNull!.code, 'OFFER_EXPIRED');
    expect(c.read(homeControllerProvider).value!.offer, isNull);
  });
}
