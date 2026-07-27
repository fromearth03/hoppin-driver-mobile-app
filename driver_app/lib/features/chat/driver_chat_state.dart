import 'package:flutter/foundation.dart';

/// Immutable snapshot of the driver's chat send surface (riblet convention:
/// hand-rolled immutable + copyWith with the `_unset` sentinel, in the
/// [DocumentsState] style).
///
/// The THREAD itself is not in here — it lives in `driverChatStreamProvider`,
/// the polling read. This state is only the send side: whether a send is in
/// flight, whether the server has closed the thread for good, and the last
/// transient error to surface.
@immutable
class DriverChatState {
  /// Creates a chat send-surface snapshot. Defaults to idle and open.
  const DriverChatState({
    this.sending = false,
    this.chatClosed = false,
    this.error,
  });

  /// A send is in flight. One at a time — [DriverChatInteractor.send] returns
  /// early while this is true.
  final bool sending;

  /// 🔴 TERMINAL. Set by exactly ONE thing: the server answering
  /// `code == 'CHAT_CLOSED'`. Not by a 409. Not by a timeout. Not by the trip
  /// phase. The SERVER's code is the authority on whether this thread is open;
  /// any client-side mirror is UX and must never become the correctness check.
  ///
  /// When true the composer and the template chips leave the TREE. A snackbar
  /// over a live composer would disguise a permanent close as a hiccup, and the
  /// driver would keep retyping a message that can never send — at the kerb, on
  /// a job, with the rider waiting.
  final bool chatClosed;

  /// Display-ready message from the last transient send failure, if any. A
  /// CHAT_CLOSED never lands here — it is terminal, not transient.
  final String? error;

  static const Object _unset = Object();

  /// copyWith with explicit null-clearing for [error]: passing `null` clears,
  /// omitting keeps.
  DriverChatState copyWith({
    bool? sending,
    bool? chatClosed,
    Object? error = _unset,
  }) {
    return DriverChatState(
      sending: sending ?? this.sending,
      chatClosed: chatClosed ?? this.chatClosed,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}
