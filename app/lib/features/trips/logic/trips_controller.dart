import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/models/driver_trip.dart';
import '../data/trips_repository.dart';

class TripsState {
  final TripFilter filter;
  final List<DriverTrip> trips;
  final String? nextCursor;
  final bool isLoadingMore;
  final ApiException? error;

  const TripsState({
    this.filter = TripFilter.all,
    this.trips = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.error,
  });

  bool get hasMore => nextCursor != null;

  TripsState copyWith({
    TripFilter? filter,
    List<DriverTrip>? trips,
    String? nextCursor,
    bool? isLoadingMore,
    ApiException? error,
    bool clearCursor = false,
    bool clearError = false,
  }) =>
      TripsState(
        filter: filter ?? this.filter,
        trips: trips ?? this.trips,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class TripsController extends AsyncNotifier<TripsState> {
  bool _disposed = false;

  /// Incremented on every filter change. A response whose ticket is stale
  /// is dropped: without this a slow earlier request can land after a fast
  /// later one and show the driver a filter they did not choose.
  int _request = 0;

  @override
  Future<TripsState> build() async {
    ref.onDispose(() => _disposed = true);
    return _fetch(TripFilter.all);
  }

  TripsState get _current => state.value ?? const TripsState();

  void _emit(TripsState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  Future<TripsState> _fetch(TripFilter filter) async {
    final result = await ref.read(tripsRepositoryProvider).page(filter: filter);
    return result.when(
      ok: (page) => TripsState(
        filter: filter,
        trips: page.trips,
        nextCursor: page.nextCursor,
      ),
      err: (e) => TripsState(filter: filter, error: e),
    );
  }

  Future<void> setFilter(TripFilter filter) async {
    if (filter == _current.filter) return;
    // Refetched rather than filtered in place: the server owns which rows
    // belong to a filter, and a client-side filter would page wrongly.
    final ticket = ++_request;
    state = const AsyncLoading();
    final next = await _fetch(filter);
    if (ticket != _request) return;
    _emit(next);
  }

  Future<void> refresh() async {
    final ticket = ++_request;
    final next = await _fetch(_current.filter);
    if (ticket != _request) return;
    _emit(next);
  }

  Future<void> loadMore() async {
    final cursor = _current.nextCursor;
    if (cursor == null || _current.isLoadingMore) return;

    _emit(_current.copyWith(isLoadingMore: true));
    final result = await ref
        .read(tripsRepositoryProvider)
        .page(filter: _current.filter, cursor: cursor);
    result.when(
      ok: (page) => _emit(_current.copyWith(
        trips: [..._current.trips, ...page.trips],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      )),
      err: (e) => _emit(_current.copyWith(isLoadingMore: false, error: e)),
    );
  }
}

final tripsControllerProvider =
    AsyncNotifierProvider<TripsController, TripsState>(TripsController.new);
