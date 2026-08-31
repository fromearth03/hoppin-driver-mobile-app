import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/appeals_repository.dart';
import '../data/models/appeal.dart';
import '../data/models/driver_stats.dart';
import '../data/models/penalty.dart';
import '../data/stats_repository.dart';

class StatsState {
  final DriverStats? stats;
  final PenaltyList? penalties;
  final List<Appeal> appeals;
  final ApiException? error;

  /// What the picker is currently set to. Held here rather than in the
  /// widget so a refresh re-asks for the same window.
  final StatsPeriod period;

  const StatsState({
    this.stats,
    this.penalties,
    this.appeals = const [],
    this.error,
    this.period = StatsPeriod.month,
  });
}

class StatsController extends AsyncNotifier<StatsState> {
  bool _disposed = false;

  /// The design opens on "This Month".
  StatsPeriod _period = StatsPeriod.month;

  @override
  Future<StatsState> build() async {
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  Future<StatsState> _fetch() async {
    final statsRepo = ref.read(statsRepositoryProvider);
    final stats = await statsRepo.stats(period: _period);
    final penalties = await statsRepo.penalties();
    final appeals = await ref.read(appealsRepositoryProvider).mine();

    return StatsState(
      stats: stats.valueOrNull,
      penalties: penalties.valueOrNull,
      appeals: appeals.valueOrNull ?? const [],
      error: stats.errorOrNull,
      period: _period,
    );
  }

  /// Re-asks the service for a different window. Only the stats change; the
  /// penalties and appeals lists are not period-scoped.
  Future<void> setPeriod(StatsPeriod period) async {
    if (period == _period) return;
    _period = period;
    await refresh();
  }

  Future<void> refresh() async {
    final next = await _fetch();
    if (_disposed) return;
    state = AsyncData(next);
  }
}

final statsControllerProvider =
    AsyncNotifierProvider<StatsController, StatsState>(StatsController.new);
