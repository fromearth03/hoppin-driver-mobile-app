import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raised the first time a call comes back SESSION_REPLACED.
///
/// The service allows one live session per driver, so signing in elsewhere
/// invalidates this device and every call from here on answers 401. Nothing
/// on screen can load, and each failure would otherwise become its own
/// snackbar — a stack of them saying the same thing.
///
/// Set once and never cleared by the app itself: leaving it set is what stops
/// twenty in-flight calls from each raising the screen again. Signing out
/// rebuilds the container, which resets it.
class SessionLost extends Notifier<bool> {
  @override
  bool build() => false;

  void raise() {
    if (!state) state = true;
  }
}

final sessionLostProvider =
    NotifierProvider<SessionLost, bool>(SessionLost.new);
