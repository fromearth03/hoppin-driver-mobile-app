import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money.dart';
import '../data/ledger_repository.dart';
import '../data/models/ledger_entry.dart';

class StatementState {
  final Pence balance;
  final List<LedgerEntry> entries;
  final String? nextCursor;
  final bool isLoadingMore;
  final ApiException? error;

  const StatementState({
    this.balance = const Pence(0),
    this.entries = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.error,
  });

  bool get hasMore => nextCursor != null;

  StatementState copyWith({
    Pence? balance,
    List<LedgerEntry>? entries,
    String? nextCursor,
    bool? isLoadingMore,
    ApiException? error,
    bool clearCursor = false,
    bool clearError = false,
  }) =>
      StatementState(
        balance: balance ?? this.balance,
        entries: entries ?? this.entries,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class StatementController extends AsyncNotifier<StatementState> {
  bool _disposed = false;

  @override
  Future<StatementState> build() async {
    ref.onDispose(() => _disposed = true);
    final result = await ref.read(ledgerRepositoryProvider).page();
    return result.when(
      ok: (page) => StatementState(
        balance: page.balance,
        entries: page.entries,
        nextCursor: page.nextCursor,
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
    final result = await ref.read(ledgerRepositoryProvider).page();
    result.when(
      ok: (page) => _emit(StatementState(
        balance: page.balance,
        entries: page.entries,
        nextCursor: page.nextCursor,
      )),
      err: (e) => _emit(_current.copyWith(error: e)),
    );
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
