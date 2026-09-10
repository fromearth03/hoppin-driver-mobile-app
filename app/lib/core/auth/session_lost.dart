import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Why the session ended, when it ended for a reason the driver must be told.
///
/// The screen that follows says something different for each, and getting it
/// wrong is worse than saying nothing: telling a deleted driver they "signed
/// in on another device" sends them to look for a phone that does not exist.
enum SessionEndReason {
  /// One live session per driver; signing in elsewhere invalidated this one.
  /// The only reason a driver can recover from on their own.
  replaced,

  /// The account was erased under GDPR. The GoTrue login is gone too, so
  /// signing in again fails as well — there is nothing to come back to.
  deleted,

  /// Banned or suspended by an operator, or the device is blacklisted.
  blocked,
}

/// Raised the first time a call comes back with a session-ending code.
///
/// Every call from here on will fail the same way. Nothing on screen can load,
/// and each failure would otherwise become its own snackbar — a stack of them
/// saying the same thing.
///
/// Set once and never cleared by the app itself: leaving it set is what stops
/// twenty in-flight calls from each raising the screen again. Signing out
/// rebuilds the container, which resets it.
///
/// 🔴 THE FIRST REASON WINS. A banned driver's next call may well answer
/// `AUTH_REQUIRED` once the service drops them, and overwriting `blocked` with
/// `replaced` would swap a true explanation for a false one.
class SessionLost extends Notifier<SessionEndReason?> {
  @override
  SessionEndReason? build() => null;

  void raise(SessionEndReason reason) {
    state ??= reason;
  }
}

final sessionLostProvider =
    NotifierProvider<SessionLost, SessionEndReason?>(SessionLost.new);

/// The codes that end a session, and what each one means.
///
/// Anything absent from here is an ordinary failure the screen handles itself.
const sessionEndingCodes = <String, SessionEndReason>{
  'SESSION_REPLACED': SessionEndReason.replaced,
  // A 401 with a dead token. Signing in again is the remedy, so it reads as
  // a replaced session rather than a block.
  'AUTH_REQUIRED': SessionEndReason.replaced,
  'ACCOUNT_DELETED': SessionEndReason.deleted,
  'ACCOUNT_BANNED': SessionEndReason.blocked,
  'ACCOUNT_SUSPENDED': SessionEndReason.blocked,
  'DEVICE_BLACKLISTED': SessionEndReason.blocked,
};
