import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_status_repository.dart';
import '../data/models/app_status.dart';

/// How often the gate is re-read while the app is open.
///
/// An operator arming maintenance needs it to reach drivers who are already
/// running, not only those who happen to launch afterwards. Slow enough to
/// cost nothing over a shift.
const appGateInterval = Duration(minutes: 5);

/// Holds the launch gate.
///
/// Opens rather than blocks on failure. A driver mid-shift losing signal, or
/// a status endpoint having a bad minute, must never be shown a maintenance
/// wall the operator did not arm — the cost of a missed gate is one stale
/// client, the cost of a false one is a fleet that cannot work.
class AppGateController extends AsyncNotifier<AppStatus> {
  Timer? _timer;

  @override
  Future<AppStatus> build() async {
    ref.onDispose(() => _timer?.cancel());
    _timer = Timer.periodic(appGateInterval, (_) => refresh());
    return _read();
  }

  Future<AppStatus> _read() async {
    final result = await ref.read(appStatusRepositoryProvider).read();
    return result.valueOrNull ?? AppStatus.open;
  }

  Future<void> refresh() async {
    final next = await _read();
    // Only a change is worth a rebuild: this runs every five minutes for the
    // life of the app, and the answer is almost always the same.
    if (state.value?.gate != next.gate) state = AsyncData(next);
  }
}

final appGateProvider =
    AsyncNotifierProvider<AppGateController, AppStatus>(AppGateController.new);
