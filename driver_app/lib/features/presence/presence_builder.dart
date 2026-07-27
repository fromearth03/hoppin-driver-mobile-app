import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presence_interactor.dart';
import 'presence_state.dart';
import 'shift_service.dart';

/// The driver-app-local ANDROID FOREGROUND SERVICE seam (Phase 2).
///
/// It lives HERE, not in `hoppin_shared`, for the same reason
/// `driverLocationServiceProvider` does: the isolation contract keeps
/// `flutter_foreground_task` out of `hoppin_shared` / `hoppin_demo` /
/// `hoppin_ui`, and a grep enforces it.
///
/// 🔴 THE DEFAULT IS THE NO-OP, NOT THE ANDROID IMPL. That inverts the location
/// seam's default, and deliberately: `main.dart` overrides this with
/// [AndroidDriverShiftService] only when actually running on Android. Everything
/// else — every widget test, every unit test, the demo, a desktop dev run — gets
/// [NoopDriverShiftService], which reports `false` and MEANS it. No test in this
/// repository can reach a platform channel through this provider, which is what
/// makes "no MethodChannel mocks anywhere" structurally true rather than a
/// promise.
final driverShiftServiceProvider = Provider<DriverShiftService>(
  (ref) => const NoopDriverShiftService(),
);

/// Assembly point of the presence riblet (DOCS/05).
///
/// A SERVICE riblet: interactor + state, no view, no router, no route. Nothing
/// navigates on presence and nothing routes to it — it is the app's heartbeat,
/// and the only thing it renders is the seam-#84 rung the dashboard mounts when
/// the device will not give us a fix.
///
/// NOT autoDispose, deliberately. The heartbeat must outlive the dashboard
/// WIDGET: a driver who walks into the trip runner, or backgrounds the app
/// mid-shift, is still online and still owes the server a ping every 20
/// seconds. An autoDispose provider would tear the timer down the moment the
/// last widget stopped watching it — which is precisely the five-minutes-and-
/// you-are-dropped bug, rebuilt.
final presenceInteractorProvider =
    NotifierProvider<PresenceInteractor, PresenceState>(
  PresenceInteractor.new,
);
