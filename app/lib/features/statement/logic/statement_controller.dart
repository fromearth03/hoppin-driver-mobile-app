import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../../../core/result.dart';
import '../data/ledger_repository.dart';
import '../data/models/ledger_entry.dart';
import '../data/models/ledger_summary.dart';

class StatementState {
  final Pence balance;
  final List<LedgerEntry> entries;

  /// The period breakdown behind the balance panel. Null when the summary
  /// call failed — the statement itself still renders, because a missing
  /// breakdown is no reason to withhold the balance and the entries.
  final LedgerSummary? summary;
  final String? nextCursor;
  final bool isLoadingMore;
  final ApiException? error;

  const StatementState({
    this.balance = const Pence(0),
    this.entries = const [],
    this.summary,
    this.nextCursor,
    this.isLoadingMore = false,
    this.error,
  });

  bool get hasMore => nextCursor != null;

  StatementState copyWith({
    Pence? balance,
    List<LedgerEntry>? entries,
    LedgerSummary? summary,
    String? nextCursor,
    bool? isLoadingMore,
    ApiException? error,
    bool clearCursor = false,
    bool clearError = false,
  }) =>
      StatementState(
        balance: balance ?? this.balance,
        entries: entries ?? this.entries,
        summary: summary ?? this.summary,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class StatementController extends AsyncNotifier<StatementState> {
  bool _disposed = false;

  /// The period the balance panel breaks down. The handler accepts only
  /// 'week' and 'month'.
  static const _period = 'week';

  @override
  Future<StatementState> build() async {
    ref.onDispose(() => _disposed = true);
    return _load();
  }

  /// Reads the page and the period breakdown together. They are independent
  /// calls, so they go out in parallel — and a failed summary loses only the
  /// itemised rows, never the balance or the entries.
  Future<StatementState> _load() async {
    final repo = ref.read(ledgerRepositoryProvider);
    final results =
        await Future.wait([repo.page(), repo.summary(_period)]);
    final page = results[0] as Result<LedgerPage>;
    final summary = results[1] as Result<LedgerSummary>;

    return page.when(
      ok: (p) => StatementState(
        balance: p.balance,
        entries: p.entries,
        summary: summary.valueOrNull,
        nextCursor: p.nextCursor,
      ),
      err: (e) => StatementState(error: e),
    );
  }

  StatementState get _current => state.value ?? const StatementState();

  void _emit(StatementState next) {
    if (_disposed) return;
    state = AsyncData(next);
  }

  Future<void> refresh() async {
    final next = await _load();
    // A failed refresh keeps what is on screen rather than blanking it.
    _emit(next.error != null ? _current.copyWith(error: next.error) : next);
  }

  Future<void> loadMore() async {
    final cursor = _current.nextCursor;
    // Guarded rather than merely hidden in the UI: a double tap or a rebuild
    // mid-flight would otherwise append the same page twice.
    if (cursor == null || _current.isLoadingMore) return;

    _emit(_current.copyWith(isLoadingMore: true));
    final result =
        await ref.read(ledgerRepositoryProvider).page(cursor: cursor);
    result.when(
      ok: (page) => _emit(_current.copyWith(
        entries: [..._current.entries, ...page.entries],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      )),
      err: (e) => _emit(_current.copyWith(isLoadingMore: false, error: e)),
    );
  }
}

final statementControllerProvider =
    AsyncNotifierProvider<StatementController, StatementState>(
        StatementController.new);
