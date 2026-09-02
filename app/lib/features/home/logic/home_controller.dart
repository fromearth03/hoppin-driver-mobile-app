import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/result.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../auth/data/auth_repository.dart';
import '../../../core/api/api_client.dart';
import '../../../core/push/push_service.dart';
import '../data/driver_status_repository.dart';
import 'location_reporter.dart';
import 'offer_labels.dart';
import '../data/models/driver_status.dart';
import '../data/models/driver_today.dart';
import '../data/models/pending_offer.dart';
import '../data/offer_repository.dart';

class HomeState {
  final DriverStatus? status;
  final DriverToday? today;
  final PendingOffer? offer;
  final bool isBusy;
  final ApiException? error;

  /// When THIS session put the driver online, or null when it did not.
  ///
  /// A relaunch mid-shift leaves it null even though the driver is online:
  /// nothing was started here, so there is no first fix on its way and a
  /// stale reading is the plain truth rather than a race.
  final DateTime? onlineSince;

  const HomeState({
    this.status,
    this.today,
    this.offer,
    this.isBusy = false,
    this.error,
    this.onlineSince,
  });

  HomeState copyWith({
    DriverStatus? status,
    DriverToday? today,
    PendingOffer? offer,
    bool? isBusy,
    ApiException? error,
    DateTime? onlineSince,
    bool clearOffer = false,
    bool clearError = false,
    bool clearOnlineSince = false,
  }) =>
      HomeState(
        status: status ?? this.status,
        today: today ?? this.today,
        offer: clearOffer ? null : (offer ?? this.offer),
        isBusy: isBusy ?? this.isBusy,
        error: clearError ? null : (error ?? this.error),
        onlineSince:
            clearOnlineSince ? null : (onlineSince ?? this.onlineSince),
      );

  /// On shift as far as the dispatcher is concerned. `stale` counts: the
  /// driver is still marked online server-side, their GPS has just gone
  /// quiet. Reading stale as offline would show them an "off" toggle while
  /// they remain dispatchable, and tapping it would re-send `goOnline`.
  bool get isOnline =>
      status?.presence == Presence.online || status?.presence == Presence.stale;

  /// Online *and* reachable — the only state in which polling for offers is
  /// worthwhile, since a stale driver will not be dispatched anyway.
  bool get isDispatchable => status?.presence == Presence.online;

  bool get onTrip => status?.activeRideId != null;

  /// Whether to tell the driver their location is missing.
  ///
  /// True only once a first fix has had a fair chance to land: the server
  /// marks a driver stale the moment they go online, and warning on that
  /// reading accused them before the GPS had answered.
  bool get showsNoLocationWarning =>
      status?.presence == Presence.stale &&
      shouldWarnNoLocation(onlineSince: onlineSince, now: DateTime.now());
}

/// Overridable so tests do not wait five real seconds.
final pollIntervalProvider =
    Provider<Duration>((ref) => const Duration(seconds: 5));

/// How long a driver who has just gone online is given to land a first GPS
/// fix before the app says their location is missing.
///
/// Going online marks them stale server-side immediately — no beat has
/// arrived yet — and the status read that follows the POST happens in the
/// same breath. Warning on that reading blames the driver for a fix that has
/// had no chance to arrive, and it was the first thing they saw every single
/// time they started a shift.
const locationGrace = Duration(seconds: 10);

/// Whether "we can't see your location" is fair to show yet.
///
/// [onlineSince] is when this session put the driver online, or null when it
/// did not — an app resumed mid-shift has no fix in flight of its own, so a
/// stale reading there is the truth straight away.
bool shouldWarnNoLocation({
  required DateTime? onlineSince,
  required DateTime now,
}) {
  if (onlineSince == null) return true;
  return now.difference(onlineSince) >= locationGrace;
}

class HomeController extends AsyncNotifier<HomeState> {
  Timer? _timer;
  bool _disposed = false;

  /// The offer the driver has already acted on. A decline, or an accept that
  /// came back OFFER_EXPIRED, means this one is finished — but the server may
  /// still list it for a tick or two, and re-rendering a card the driver was
  /// just told had lapsed reads as a bug.
  String? _dismissedOfferId;

  DriverStatusRepository get _statusRepo =>
      ref.read(driverStatusRepositoryProvider);
  OfferRepository get _offerRepo => ref.read(offerRepositoryProvider);

  @override
  Future<HomeState> build() async {
    // Captured now: reading a provider inside onDispose hits a container
    // that is already torn down.
    final reporter = ref.read(locationReporterProvider);
    ref.onDispose(() {
      _disposed = true;
      stopPolling();
      reporter.stop();
    });
    // Ride offers arrive as notifications on Android 13+; asking here —
    // on the working screen, once — beats a blanket splash prompt. Web
    // and already-granted answer instantly.
    if (!kIsWeb) {
      // Best-effort and crash-proof: without the platform channel (tests,
      // exotic platforms) the request can throw synchronously OR
      // asynchronously; neither may take the controller down with it.
      try {
        Permission.notification
            .request()
            .catchError((_) => PermissionStatus.denied);
      } catch (_) {}
      // The wake-up half of offer delivery: register this device's FCM
      // token and route a foreground ride-offer push straight to the
      // authoritative fetch. Fire-and-forget — a device without Google
      // services still gets every offer from the 5s poll.
      final push = ref.read(pushServiceProvider);
      push.onRideOffer = () => onPushWake();
      push.register();
    }
    final result = await _statusRepo.status();
    return await result.when(
      ok: (status) async {
        final state = HomeState(status: status, today: await _today());
        // A relaunch mid-shift resumes what the toggle would have started:
        // a driver the server says is online must poll for offers and
        // report position, however the app came back to life. (Tests that
        // stub an online status own stopping the poll they trigger.)
        if (state.isOnline) {
          startPolling();
          reporter.start();
        }
        return state;
      },
      // A cold start that cannot reach /status opens on the offline screen
      // carrying the error, rather than on a full-screen failure. The driver
      // is certainly not online, and the toggle is what recovers the
      // session — putting an error page in front of it removed the one
      // control that would have helped.
      err: (e) async =>
          HomeState(status: DriverStatus.unreachable, error: e),
    );
  }

  /// The day-so-far tiles. Best-effort: losing them is not worth denying the
  /// driver the toggle and the offer card, which are what Home is for.
  Future<DriverToday?> _today() async {
    final result = await _statusRepo.today();
    return result.valueOrNull;
  }

  HomeState get _current => state.value ?? const HomeState();

  /// Every write goes through here. Requests started before the driver
  /// navigated away resolve afterwards, and Riverpod throws on assigning to
  /// a disposed notifier, so the guard belongs at the single write point.
  void _emit(HomeState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  Future<void> refresh() async {
    final result = await _statusRepo.status();
    if (_disposed) return;
    await result.when(
      ok: (status) async {
        final today = await _today();
        if (_disposed) return;
        _emit(_current.copyWith(
            status: status, today: today, clearError: true));
      },
      err: (e) async => _emit(_current.copyWith(error: e)),
    );
  }

  /// One shot at winning the session back: web tab and phone fight over
  /// the single live session the backend allows, and the loser's every
  /// call is 401 SESSION_REPLACED. A deliberate tap on the toggle is the
  /// driver saying "use it HERE" — so re-claim once and retry, rather
  /// than freezing on an error the driver cannot read.
  Future<Result<T>> _withSessionRetry<T>(
      Future<Result<T>> Function() call) async {
    final first = await call();
    if (first.isOk || first.errorOrNull?.code != 'SESSION_REPLACED') {
      return first;
    }
    await ref.read(authRepositoryProvider).claimSession(
        ref.read(apiClientProvider));
    return call();
  }

  Future<void> toggleOnline() async {
    state = AsyncData(_current.copyWith(isBusy: true, clearError: true));

    if (_current.isOnline) {
      final result = await _withSessionRetry(_statusRepo.goOffline);
      await result.when(
        ok: (_) async {
          stopPolling();
          ref.read(locationReporterProvider).stop();
          await refresh();
          _emit(_current.copyWith(
              isBusy: false, clearOffer: true, clearOnlineSince: true));
        },
        // A failed go-offline leaves the driver online and dispatchable
        // server-side. Flipping the toggle off anyway would strand them
        // taking jobs the app has stopped polling for.
        err: (e) async => _emit(_current.copyWith(isBusy: false, error: e)),
      );
      return;
    }

    final result = await _withSessionRetry(_statusRepo.goOnline);
    await result.when(
      ok: (_) async {
        // Same shape as going offline: the POST acknowledges, /status is
        // the truth. Reading presence out of the acknowledgement is what
        // left the toggle off until the next poll.
        await refresh();
        // Stamped here, after the status read: the grace runs from the
        // moment the driver is actually online, and refresh() is what will
        // have reported them stale with no beat sent yet.
        _emit(_current.copyWith(isBusy: false, onlineSince: DateTime.now()));
        startPolling();
        // The dispatcher can only work a driver it can place. Refusing
        // location does not block going online — the server will mark
        // them stale and the banner explains — but it is asked for here,
        // at the moment it visibly matters.
        ref.read(locationReporterProvider).start();
      },
      err: (e) async {
        // A refusal is not an error toast — it is a state the Home screen
        // renders as a resolution list. Fold the reason into the status so
        // one widget handles both the polled and refused paths.
        _emit(_current.copyWith(
          isBusy: false,
          status: _blockedFrom(e, _current.status),
        ));
      },
    );
  }

  /// Builds a blocked [DriverStatus] from a 403 refusal. `NOT_ELIGIBLE`
  /// carries its specific reason in `fields`; the other two refusal codes
  /// *are* the reason.
  DriverStatus _blockedFrom(ApiException e, DriverStatus? previous) {
    final reason = e.code == 'NOT_ELIGIBLE'
        ? (e.fields['reason'] as String?) ?? 'UNKNOWN'
        : e.code;
    final docs = ((e.fields['blocking_document_types'] as List?) ?? const [])
        .map((d) => d as String)
        .toList();
    return DriverStatus(
      presence: Presence.offline,
      staleAfterSeconds: previous?.staleAfterSeconds ?? 90,
      dispatchable: false,
      blockedReason: reason,
      blockingDocumentTypes: docs,
      activeRideId: previous?.activeRideId,
      // Carried through: a refusal says nothing about where the driver is,
      // and discarding it would make the stale-GPS check read wrong until
      // the next successful poll.
      lastLocationAt: previous?.lastLocationAt,
    );
  }

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(ref.read(pollIntervalProvider), (_) => _tick());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  /// One tick fetches offers and status together — the stale-GPS warning is
  /// as time-sensitive as an offer, and a second timer would double the load.
  Future<void> _tick() async {
    if (_disposed) return;

    // Status is read on every tick regardless of the cached presence: the
    // follow-up read after go-online can fail or lag, and a guard on the
    // cached value would leave the app showing offline forever while the
    // dispatcher considers the driver online.
    final statusResult = await _statusRepo.status();
    if (_disposed) return;
    statusResult.when(
      ok: (s) {
        _emit(_current.copyWith(status: s));
        // The server is the authority on presence. Forced offline (admin,
        // SESSION_REPLACED) must also silence the GPS beat — the toggle
        // callbacks alone would leave it running forever.
        if (!_current.isOnline) {
          ref.read(locationReporterProvider).stop();
        }
      },
      err: (_) {},
    );

    if (!_canReceiveOffers) return;

    final offersResult = await _offerRepo.offers();
    // Re-checked after the await: the driver may have gone offline or
    // accepted a ride while this request was in flight, and committing the
    // result then would put a card back on top of a driver already driving.
    if (!_canReceiveOffers) return;
    // A failed poll is not worth surfacing; the next tick retries.
    final list = offersResult.valueOrNull;
    if (list == null) return;
    final fresh = _withoutDismissed(list);
    if (fresh.isEmpty) {
      _emit(_current.copyWith(clearOffer: true));
      return;
    }
    // The card first, the street names after: a driver has ~60 seconds to
    // decide, and holding the offer hostage to a geocoder would spend them.
    _emit(_current.copyWith(offer: fresh.first));
    _enrich(fresh.first);
  }

  /// Fills in addresses and the multi-stop shape, then re-emits — unless
  /// the offer has moved on underneath the lookup.
  void _enrich(PendingOffer offer) {
    final resolver = ref.read(offerLabelResolverProvider);
    unawaited(resolver.resolve(offer).then((enriched) {
      if (_disposed || _current.offer?.id != offer.id) return;
      _emit(_current.copyWith(offer: enriched));
    }).catchError((_) {}));
  }

  bool get _canReceiveOffers =>
      !_disposed && _current.isDispatchable && !_current.onTrip;

  /// Called when an FCM ride-offer push wakes the app. The push payload is
  /// a trigger only — nothing in it is rendered.
  Future<void> onPushWake() async {
    final result = await _offerRepo.offers();
    if (_disposed) return;
    final fresh = _withoutDismissed(result.valueOrNull ?? const []);
    if (fresh.isEmpty) return;
    _emit(_current.copyWith(offer: fresh.first));
    _enrich(fresh.first);
  }

  /// Drops the offer already acted on, and forgets the id once the server
  /// stops sending it so a later, genuinely new offer is never suppressed.
  ///
  /// Lapsed offers go the same way. The poll clears them on its next tick,
  /// but the driver is looking at the card in between — and once they are
  /// offline, or the network drops, there is no next tick at all, so a dead
  /// card would sit there with a button the server refuses.
  List<PendingOffer> _withoutDismissed(List<PendingOffer> list) {
    final live = list.where((o) => !o.hasExpired).toList();
    if (_dismissedOfferId == null) return live;
    final remaining = live.where((o) => o.id != _dismissedOfferId).toList();
    if (remaining.length == live.length) _dismissedOfferId = null;
    return remaining;
  }

  Future<Result<String>> acceptOffer() async {
    final offer = _current.offer;
    if (offer == null) {
      return Err(ApiException('OFFER_NOT_FOUND', 'no offer on screen', 404));
    }
    // Stopped before the request, not after: an in-flight tick that resolved
    // mid-accept could otherwise re-render the offer being accepted.
    stopPolling();
    _emit(_current.copyWith(isBusy: true));
    final result = await _offerRepo.accept(offer.id, rideId: offer.rideId);

    // Either way the card comes down: accepted offers become a trip, and a
    // lapsed one must not linger looking tappable.
    _dismissedOfferId = offer.id;
    _emit(_current.copyWith(isBusy: false, clearOffer: true));
    // A failed accept leaves the driver online and waiting, so resume the
    // safety net; only a successful one hands over to the trip screen.
    if (!result.isOk && _canReceiveOffers) startPolling();
    return result;
  }

  /// Takes down an offer whose window closed while it was on screen.
  ///
  /// Deliberately silent: the driver did not refuse this job, they simply
  /// ran out of time, and dispatch already knows — the offer expired on its
  /// side too. Sending a decline here would record a refusal against them
  /// for a ride they may well have wanted.
  ///
  /// The id is suppressed so a poll mid-flight cannot put the dead card
  /// back, and polling continues: the next offer is the one that matters.
  void expireOffer() {
    final offer = _current.offer;
    if (offer == null) return;
    _dismissedOfferId = offer.id;
    _emit(_current.copyWith(clearOffer: true));
  }

  Future<void> declineOffer() async {
    final offer = _current.offer;
    if (offer == null) return;
    _dismissedOfferId = offer.id;
    _emit(_current.copyWith(clearOffer: true));
    await _offerRepo.decline(offer.id);
  }
}

final homeControllerProvider =
    AsyncNotifierProvider<HomeController, HomeState>(HomeController.new);
