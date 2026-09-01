import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/result.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../auth/data/auth_repository.dart';
import '../../../core/api/api_client.dart';
import '../data/driver_status_repository.dart';
import 'location_reporter.dart';
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

  const HomeState({
    this.status,
    this.today,
    this.offer,
    this.isBusy = false,
    this.error,
  });

  HomeState copyWith({
    DriverStatus? status,
    DriverToday? today,
    PendingOffer? offer,
    bool? isBusy,
    ApiException? error,
    bool clearOffer = false,
    bool clearError = false,
  }) =>
      HomeState(
        status: status ?? this.status,
        today: today ?? this.today,
        offer: clearOffer ? null : (offer ?? this.offer),
        isBusy: isBusy ?? this.isBusy,
        error: clearError ? null : (error ?? this.error),
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
}

/// Overridable so tests do not wait five real seconds.
final pollIntervalProvider =
    Provider<Duration>((ref) => const Duration(seconds: 5));

/// Owns presence, blockers and the current offer.
///
/// FCM is the primary path — a push wakes the app and calls [onPushWake],
/// which fetches the authoritative offer. The 5s poll is a safety net for
/// Android OEM battery managers that silently drop high-priority pushes; it
/// runs only while online and off-trip, so an idle or driving app is quiet.
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
      err: (e) async => HomeState(error: e),
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
          _emit(_current.copyWith(isBusy: false, clearOffer: true));
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
        _emit(_current.copyWith(isBusy: false));
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
    offersResult.when(
      ok: (list) {
        final fresh = _withoutDismissed(list);
        _emit(fresh.isEmpty
            ? _current.copyWith(clearOffer: true)
            : _current.copyWith(offer: fresh.first));
      },
      // A failed poll is not worth surfacing; the next tick retries.
      err: (_) {},
    );
  }

  bool get _canReceiveOffers =>
      !_disposed && _current.isDispatchable && !_current.onTrip;

  /// Called when an FCM ride-offer push wakes the app. The push payload is
  /// a trigger only — nothing in it is rendered.
  Future<void> onPushWake() async {
    final result = await _offerRepo.offers();
    if (_disposed) return;
    result.when(
      ok: (list) {
        final fresh = _withoutDismissed(list);
        if (fresh.isNotEmpty) {
          _emit(_current.copyWith(offer: fresh.first));
        }
      },
      err: (_) {},
    );
  }

  /// Drops the offer already acted on, and forgets the id once the server
  /// stops sending it so a later, genuinely new offer is never suppressed.
  List<PendingOffer> _withoutDismissed(List<PendingOffer> list) {
    if (_dismissedOfferId == null) return list;
    final remaining =
        list.where((o) => o.id != _dismissedOfferId).toList();
    if (remaining.length == list.length) _dismissedOfferId = null;
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
