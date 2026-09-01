import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/documents_repository.dart';
import '../data/models/driver_document.dart';

class DocumentsController extends AsyncNotifier<List<DocumentSlot>> {
  bool _disposed = false;

  @override
  Future<List<DocumentSlot>> build() async {
    ref.onDispose(() => _disposed = true);
    final result = await ref.read(documentsRepositoryProvider).slots();
    return result.when(
      ok: (slots) => slots,
      err: (e) => throw e,
    );
  }

  Future<void> refresh() async {
    final result = await ref.read(documentsRepositoryProvider).slots();
    if (_disposed) return;
    result.when(
      ok: (slots) => state = AsyncData(slots),
      // A failed refresh over a list already on screen keeps the list — a
      // background revalidate on a flaky link must not blank eight tiles
      // into an error page. The error state is only for having nothing.
      err: (e) {
        if (!state.hasValue) state = AsyncError(e, StackTrace.current);
      },
    );
  }
}

final documentsControllerProvider =
    AsyncNotifierProvider<DocumentsController, List<DocumentSlot>>(
        DocumentsController.new);
