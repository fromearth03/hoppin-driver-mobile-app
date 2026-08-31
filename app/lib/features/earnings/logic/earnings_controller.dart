import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../trips/data/models/driver_trip.dart';
import '../../trips/data/trips_repository.dart';
import '../data/earnings_repository.dart';
import '../data/models/driver_promotion.dart';
import '../data/models/ride_earnings.dart';
import '../data/models/wallet.dart';

/// The four periods the service accepts, in the order the design's 2x2 grid
/// reads them. Anything outside this set is a 400 from the summary endpoint.
const earningsPeriods = ['today', 'week', 'month', 'all'];

class EarningsState {
  final String period;

  /// Every period's total, keyed by period name. The design shows all four
  /// at once, so all four are fetched — the selected one is simply the card
  /// whose breakdown is expanded beneath the grid.
  final Map<String, EarningsSummary> summaries;
  final Wallet? wallet;
  final List<DriverPromotion> promotions;

  /// The most recent trips in the selected period, for the trip strip. Empty
  /// when the range has none, or when the trips call failed — a bonus panel
  /// must not take down the money already earned above it.
  final List<DriverTrip> recentTrips;

  /// When the data on screen was actually fetched. Drives the design's
  /// "Last updated" pill; it is the client's own clock, not a server field.
  final DateTime? fetchedAt;
  final ApiException? error;

  const EarningsState({
    this.period = 'week',
    this.summaries = const {},
    this.wallet,
    this.promotions = const [],
    this.recentTrips = const [],
    this.fetchedAt,
    this.error,
  });

  EarningsSummary? get summary => summaries[period];
}

class EarningsController extends AsyncNotifier<EarningsState> {
  bool _disposed = false;

  /// Incremented on every period change. A stale response is dropped —
  /// showing a week's total under a "Month" label is money against the
  /// wrong question.
  int _request = 0;

  @override
  Future<EarningsState> build() async {
    ref.onDispose(() => _disposed = true);
    _period = 'week';
    return _fetch(_period);
  }

  /// The period currently in effect. Held here rather than read back off
  /// `state.value`, because `setPeriod` clears state to loading before its
  /// fetch and a refresh landing in that window would otherwise fall back
  /// to the default and quietly refetch the wrong period.
  String _period = 'week';

  void _emit(EarningsState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  Future<EarningsState> _fetch(String period) async {
    final repo = ref.read(earningsRepositoryProvider);

    // All four totals: the grid shows every period at once, so a period
    // change must not blank the other three cards.
    final results = await Future.wait(earningsPeriods.map(repo.summary));
    final summaries = <String, EarningsSummary>{};
    ApiException? summaryError;
    for (var i = 0; i < earningsPeriods.length; i++) {
      final value = results[i].valueOrNull;
      if (value != null) {
        summaries[earningsPeriods[i]] = value;
      } else if (earningsPeriods[i] == period) {
        // Only the selected period failing is an error worth showing; a
        // dead "All time" card should not blank the week the driver came
        // to look at.
        summaryError = results[i].errorOrNull;
      }
    }

    final wallet = await repo.wallet();
    final promotions = await repo.promotions();
    final trips = await _trips(summaries[period]);

    return EarningsState(
      period: period,
      summaries: summaries,
      wallet: wallet.valueOrNull,
      // Bonuses are a bonus. Failing to load them must not turn the earnings
      // screen into an error page over money the driver has already earned.
      promotions: promotions.valueOrNull ?? const [],
      recentTrips: trips,
      fetchedAt: DateTime.now(),
      error: summaryError ?? wallet.errorOrNull,
    );
  }

  /// The trips behind the selected period's total, bounded by the window the
  /// summary itself reported. Without a summary there is no window, so no
  /// trips are requested rather than a guessed range being sent.
  Future<List<DriverTrip>> _trips(EarningsSummary? summary) async {
    if (summary?.from == null) return const [];
    final page = await ref.read(tripsRepositoryProvider).page(
          filter: TripFilter.completed,
          from: summary!.from,
          // The service's `to` is exclusive; its trips filter is inclusive
          // of both days, so step back a day rather than pulling in the one
          // after the period.
          to: summary.to?.subtract(const Duration(days: 1)),
          limit: 20,
        );
    return page.valueOrNull?.trips ?? const [];
  }

  Future<void> setPeriod(String period) async {
    if (period == _period) return;
    _period = period;
    final ticket = ++_request;
    state = const AsyncLoading();
    final next = await _fetch(period);
    if (ticket != _request) return;
    _emit(next);
  }

  Future<void> refresh() async {
    final ticket = ++_request;
    final next = await _fetch(_period);
    if (ticket != _request) return;
    _emit(next);
  }
}

final earningsControllerProvider =
    AsyncNotifierProvider<EarningsController, EarningsState>(
        EarningsController.new);
