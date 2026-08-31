import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/models/driver_trip.dart';
import '../data/trips_repository.dart';

class TripsState {
  final TripFilter filter;

  /// The chosen date range, inclusive of both days. Null means every trip
  /// the filter allows.
  final DateTime? from;
  final DateTime? to;
  final List<DriverTrip> trips;
  final String? nextCursor;
  final bool isLoadingMore;
  final ApiException? error;

  const TripsState({
    this.filter = TripFilter.all,
    this.from,
    this.to,
    this.trips = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.error,
  });

  bool get hasDateRange => from != null || to != null;

  bool get hasMore => nextCursor != null;

  TripsState copyWith({
    TripFilter? filter,
    DateTime? from,
    DateTime? to,
    List<DriverTrip>? trips,
    String? nextCursor,
    bool? isLoadingMore,
    ApiException? error,
    bool clearCursor = false,
    bool clearError = false,
    bool clearDates = false,
  }) =>
      TripsState(
        filter: filter ?? this.filter,
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
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

  Future<TripsState> _fetch(TripFilter filter,
      {DateTime? from, DateTime? to}) async {
    final result = await ref
        .read(tripsRepositoryProvider)
        .page(filter: filter, from: from, to: to);
    return result.when(
      ok: (page) => TripsState(
        filter: filter,
        from: from,
        to: to,
        trips: page.trips,
        nextCursor: page.nextCursor,
      ),
      err: (e) => TripsState(filter: filter, from: from, to: to, error: e),
    );
  }

  /// Narrows to a date range, or clears it when both are null. Refetched
  /// rather than filtered in place, for the same reason the status filter is:
  /// the server owns which rows belong to a range, and paging a
  /// client-filtered list would skip rows.
  Future<void> setDateRange(DateTime? from, DateTime? to) async {
    final ticket = ++_request;
    state = const AsyncLoading();
    final next = await _fetch(_current.filter, from: from, to: to);
    if (ticket != _request) return;
    _emit(next);
  }

  Future<void> setFilter(TripFilter filter) async {
    if (filter == _current.filter) return;
    // Refetched rather than filtered in place: the server owns which rows
    // belong to a filter, and a client-side filter would page wrongly.
    final ticket = ++_request;
    state = const AsyncLoading();
    // The date range survives a status change: the driver narrowed to a
    // month and is now asking which of those were cancelled.
    final next =
        await _fetch(filter, from: _current.from, to: _current.to);
    if (ticket != _request) return;
    _emit(next);
  }

  Future<void> refresh() async {
    final ticket = ++_request;
    final next = await _fetch(_current.filter,
        from: _current.from, to: _current.to);
    if (ticket != _request) return;
    _emit(next);
  }

  Future<void> loadMore() async {
    final cursor = _current.nextCursor;
    if (cursor == null || _current.isLoadingMore) return;

    _emit(_current.copyWith(isLoadingMore: true));
    final result = await ref
        .read(tripsRepositoryProvider)
        .page(
          filter: _current.filter,
          cursor: cursor,
          // The range must ride along, or page two silently widens to every
          // trip the driver ever made.
          from: _current.from,
          to: _current.to,
        );
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
