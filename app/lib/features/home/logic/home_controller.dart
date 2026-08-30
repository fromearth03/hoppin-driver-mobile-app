import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/result.dart';
import '../data/driver_status_repository.dart';
import '../data/models/driver_status.dart';
import '../data/models/pending_offer.dart';
import '../data/offer_repository.dart';

class HomeState {
  final DriverStatus? status;
  final PendingOffer? offer;
  final bool isBusy;
  final ApiException? error;

  const HomeState({this.status, this.offer, this.isBusy = false, this.error});

  HomeState copyWith({
    DriverStatus? status,
    PendingOffer? offer,
    bool? isBusy,
    ApiException? error,
    bool clearOffer = false,
    bool clearError = false,
  }) =>
      HomeState(
        status: status ?? this.status,
        offer: clearOffer ? null : (offer ?? this.offer),
        isBusy: isBusy ?? this.isBusy,
        error: clearError ? null : (error ?? this.error),
      );

  bool get isOnline => status?.presence == Presence.online;
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

  DriverStatusRepository get _statusRepo =>
      ref.read(driverStatusRepositoryProvider);
  OfferRepository get _offerRepo => ref.read(offerRepositoryProvider);

  @override
  Future<HomeState> build() async {
    ref.onDispose(stopPolling);
    final result = await _statusRepo.status();
    return result.when(
      ok: (status) => HomeState(status: status),
      err: (e) => HomeState(error: e),
    );
  }

  HomeState get _current => state.value ?? const HomeState();

  Future<void> refresh() async {
    final result = await _statusRepo.status();
    result.when(
      ok: (status) =>
          state = AsyncData(_current.copyWith(status: status, clearError: true)),
      err: (e) => state = AsyncData(_current.copyWith(error: e)),
    );
  }

  Future<void> toggleOnline() async {
    final current = _current;
    state = AsyncData(current.copyWith(isBusy: true, clearError: true));

    if (current.isOnline) {
      await _statusRepo.goOffline();
      stopPolling();
      await refresh();
      state = AsyncData(_current.copyWith(isBusy: false, clearOffer: true));
      return;
    }

    final result = await _statusRepo.goOnline();
    result.when(
      ok: (status) {
        state = AsyncData(current.copyWith(status: status, isBusy: false));
        startPolling();
      },
      err: (e) {
        // A refusal is not an error toast — it is a state the Home screen
        // renders as a resolution list. Fold the reason into the status so
        // one widget handles both the polled and refused paths.
        state = AsyncData(current.copyWith(
          isBusy: false,
          status: _blockedFrom(e, current.status),
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
    final current = _current;
    if (!current.isOnline || current.onTrip) return;

    final offersResult = await _offerRepo.offers();
    offersResult.when(
      ok: (list) => state = AsyncData(list.isEmpty
          ? _current.copyWith(clearOffer: true)
          : _current.copyWith(offer: list.first)),
      // A failed poll is not worth surfacing; the next tick retries.
      err: (_) {},
    );

    final statusResult = await _statusRepo.status();
    statusResult.when(
      ok: (s) => state = AsyncData(_current.copyWith(status: s)),
      err: (_) {},
    );
  }

  /// Called when an FCM ride-offer push wakes the app. The push payload is
  /// a trigger only — nothing in it is rendered.
  Future<void> onPushWake() async {
    final result = await _offerRepo.offers();
    result.when(
      ok: (list) {
        if (list.isNotEmpty) {
          state = AsyncData(_current.copyWith(offer: list.first));
        }
      },
      err: (_) {},
    );
  }

  Future<Result<String>> acceptOffer() async {
    final offer = _current.offer;
    if (offer == null) {
      return Err(ApiException('OFFER_NOT_FOUND', 'no offer on screen', 404));
    }
    state = AsyncData(_current.copyWith(isBusy: true));
    final result = await _offerRepo.accept(offer.id);

    // Either way the card comes down: accepted offers become a trip, and a
    // lapsed one must not linger looking tappable.
    state = AsyncData(_current.copyWith(isBusy: false, clearOffer: true));
    if (result.isOk) stopPolling();
    return result;
  }

  Future<void> declineOffer() async {
    final offer = _current.offer;
    if (offer == null) return;
    state = AsyncData(_current.copyWith(clearOffer: true));
    await _offerRepo.decline(offer.id);
  }
}

final homeControllerProvider =
    AsyncNotifierProvider<HomeController, HomeState>(HomeController.new);
