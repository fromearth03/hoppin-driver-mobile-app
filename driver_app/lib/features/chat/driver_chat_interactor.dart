import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'driver_chat_state.dart';

/// The polling read of the thread — `GET /rides/:id/messages` on a 3s tick.
///
/// Mirrors the rider's proven `chatStreamProvider`: full fetch each tick (trips
/// are short, threads are small), and a TRANSIENT throw keeps the last list on
/// screen. An unreachable server and an empty thread look identical on the wire
/// and must never look identical on the screen.
///
/// `since` exists on the endpoint for incremental polling when this needs to
/// get smarter; the full fetch is correct and cheap for now.
final driverChatStreamProvider = StreamProvider.autoDispose
    .family<List<RideMessage>, String>((ref, rideId) async* {
  final repo = ref.watch(ridesRepositoryProvider);
  var all = <RideMessage>[];
  while (true) {
    try {
      all = await repo.messages(rideId);
      yield all;
    } on Exception {
      // Transient — keep the last list on screen. Ignorance is not emptiness.
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
});

/// THE BRAIN of the chat send surface (riblet convention: a [Notifier] with no
/// [BuildContext]). It owns `sending`, `chatClosed` and `error`.
class DriverChatInteractor extends Notifier<DriverChatState> {
  @override
  DriverChatState build() => const DriverChatState();

  /// THE ONE SEND PATH. The composer and every template chip go through it, so a
  /// chip gets byte-identical CHAT_CLOSED handling and the contract lives in
  /// exactly one place. (The rider learned this the expensive way.)
  Future<void> send(String rideId, String body) async {
    if (state.sending || state.chatClosed) return; // one in flight; never after 409
    final text = body.trim();
    if (text.isEmpty) return;
    state = state.copyWith(sending: true, error: null);
    try {
      await ref
          .read(ridesRepositoryProvider)
          .sendMessage(rideId: rideId, body: text);
      ref.invalidate(driverChatStreamProvider(rideId));
      state = state.copyWith(sending: false);
    } on ApiException catch (e) {
      // 🔴 BRANCH ON THE MACHINE CODE, NEVER ON THE STATUS NUMBER.
      //
      // 409 is CHAT_CLOSED **and** 409 is ACTIVE_TRIP_EXISTS. They are entirely
      // different worlds: one means this thread is over forever, the other means
      // something about a DIFFERENT ride. Branching on the bare 409 status would
      // take an unrelated failure and permanently kill a live conversation
      // between a driver and the rider standing on the pavement in front of them.
      //
      // The ride service normalises every failure to `{ error, code }`. The code
      // is the contract. The number is an implementation detail of HTTP.
      if (e.code == 'CHAT_CLOSED') {
        state = state.copyWith(sending: false, chatClosed: true);
        return;
      }
      state = state.copyWith(sending: false, error: friendlyErrorMessage(e));
    } on Exception catch (e) {
      // Everything else is TRANSIENT. We branch; we never swallow.
      state = state.copyWith(sending: false, error: friendlyErrorMessage(e));
    }
  }
}
