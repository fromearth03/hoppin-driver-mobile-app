import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_service.dart';

/// The last foreground push worth telling the driver about.
///
/// The push service runs far from any widget and cannot show a toast itself,
/// and the controller that wires it has no BuildContext either. So the alert
/// is parked here and the shell — which sits under every screen and does have
/// one — watches for it.
///
/// Holds one alert rather than a queue: two toasts stacked would cover the
/// screen, and with news like this the newest is the one that matters.
class PushAlertNotifier extends Notifier<PushAlert?> {
  @override
  PushAlert? build() => null;

  void post(PushAlert alert) => state = alert;

  /// Called once the toast is on screen, so a rebuild of the shell does not
  /// raise the same alert a second time.
  void consume() => state = null;
}

final pushAlertProvider =
    NotifierProvider<PushAlertNotifier, PushAlert?>(PushAlertNotifier.new);
