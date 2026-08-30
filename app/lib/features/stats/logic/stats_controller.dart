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

  const StatsState({
    this.stats,
    this.penalties,
    this.appeals = const [],
    this.error,
  });
}

class StatsController extends AsyncNotifier<StatsState> {
  bool _disposed = false;

  @override
  Future<StatsState> build() async {
    ref.onDispose(() => _disposed = true);
    return _fetch();
  }

  Future<StatsState> _fetch() async {
    final statsRepo = ref.read(statsRepositoryProvider);
    final stats = await statsRepo.stats();
    final penalties = await statsRepo.penalties();
    final appeals = await ref.read(appealsRepositoryProvider).mine();

    return StatsState(
      stats: stats.valueOrNull,
      penalties: penalties.valueOrNull,
      appeals: appeals.valueOrNull ?? const [],
      error: stats.errorOrNull,
    );
  }

  Future<void> refresh() async {
    final next = await _fetch();
    if (_disposed) return;
    state = AsyncData(next);
  }
}

final statsControllerProvider =
    AsyncNotifierProvider<StatsController, StatsState>(StatsController.new);
