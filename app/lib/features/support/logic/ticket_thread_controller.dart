import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../data/models/support_ticket.dart';
import '../data/support_repository.dart';

/// One ticket's conversation, kept fresh the same way the ride chat is: a
/// 5-second poll while the screen is open. Fetching also marks the thread
/// read server-side, so the staff sees their message landed.
class TicketThreadController
    extends AutoDisposeFamilyAsyncNotifier<TicketThread, String> {
  Timer? _timer;

  @override
  Future<TicketThread> build(String ticketId) async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    ref.onDispose(() => _timer?.cancel());

    final result = await ref.read(supportRepositoryProvider).thread(ticketId);
    return result.when(
      ok: (thread) => thread,
      err: (e) => throw e,
    );
  }

  Future<void> refresh() async {
    final result = await ref.read(supportRepositoryProvider).thread(arg);
    result.when(
      // Keep what is on screen on a failed poll — the next tick retries.
      ok: (thread) => state = AsyncData(thread),
      err: (_) {},
    );
  }

  /// Sends, then re-reads — the server owns ordering and receipts, so the
  /// message appears when the thread says it does rather than optimistically.
  Future<Result<void>> send(String body, {String? replyToId}) async {
    final result = await ref
        .read(supportRepositoryProvider)
        .reply(arg, body, replyToId: replyToId);
    if (result.isOk) await refresh();
    return result;
  }
}

final ticketThreadControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TicketThreadController, TicketThread, String>(
        TicketThreadController.new);
