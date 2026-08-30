import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/earnings_repository.dart';
import '../data/models/ride_earnings.dart';
import '../data/models/wallet.dart';

class EarningsState {
  final String period;
  final EarningsSummary? summary;
  final Wallet? wallet;
  final ApiException? error;

  const EarningsState({
    this.period = 'today',
    this.summary,
    this.wallet,
    this.error,
  });
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
    _period = 'today';
    return _fetch(_period);
  }

  /// The period currently in effect. Held here rather than read back off
  /// `state.value`, because `setPeriod` clears state to loading before its
  /// fetch and a refresh landing in that window would otherwise fall back
  /// to 'today' and quietly refetch the wrong period.
  String _period = 'today';

  void _emit(EarningsState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  Future<EarningsState> _fetch(String period) async {
    final repo = ref.read(earningsRepositoryProvider);
    final summary = await repo.summary(period);
    final wallet = await repo.wallet();

    return EarningsState(
      period: period,
      summary: summary.valueOrNull,
      wallet: wallet.valueOrNull,
      error: summary.errorOrNull ?? wallet.errorOrNull,
    );
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
