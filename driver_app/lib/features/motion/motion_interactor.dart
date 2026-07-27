import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location/location_providers.dart';
import 'motion_state.dart';

/// THE BRAIN of the motion riblet (DOCS/05) — a SERVICE riblet: interactor +
/// state, no view, no router, no route. It owns the one question the whole trip
/// surface gates on: **is the vehicle moving?**
///
/// 🔴 WHY THIS EXISTS AT ALL. `geolocator`'s `Position` has carried `speed` and
/// `speedAccuracy` on every heartbeat fix since the location service was
/// written, and `currentPosition()` threw both away on every single one. There
/// was **no speed anywhere in the driver app** — and therefore no possible
/// interaction gate, no possible glanceability rule, and nothing standing
/// between a moving driver and a keyboard. This riblet stops discarding a datum
/// we already hold. **No new GPS subscription. No new battery cost.**
///
/// TWO RULES, AND GETTING EITHER BACKWARDS SHIPS A BROKEN APP:
///
/// 1. **IGNORANCE DEGRADES OPEN.** A null speed — no fix, no permission, or a
///    platform that will not vouch for its own number — must NEVER take a
///    control away from a driver who may well be parked. We do not remove an
///    affordance on a guess.
///
///    *This is the exact mirror of the heartbeat, where ignorance degrades
///    CLOSED: no fix → no ping → not dispatchable. Both are the same rule —
///    **never assert what you do not know.** There the assertion would be "you
///    are here"; here it would be "you are driving".*
///
/// 2. **HYSTERESIS.** One threshold would strobe the composer in and out of the
///    tree every time the vehicle creeps at a red light. Two thresholds, and the
///    gate holds inside the band.
///
/// And the rule this gate does NOT enforce, said out loud so no lane
/// re-invents it: **it does not ban buttons.** A cradled phone is legal to
/// touch; that is how every Uber driver taps Accept at the wheel. Only TYPING
/// is suppressed. See [MotionState].
class MotionInteractor extends Notifier<MotionState> {
  /// The poll cadence.
  ///
  /// Deliberately far faster than the 20-second heartbeat. A driver pulls away
  /// from a pickup in a great deal less than 20 seconds, and a composer still on
  /// screen 19 seconds into the drive is precisely the sustained-attention
  /// hazard this gate exists to remove.
  static const Duration cadence = Duration(seconds: 3);

  /// How long a single fix attempt may take before the tick gives up. Shorter
  /// than the heartbeat's: a stale speed is worse than no speed.
  static const Duration fixTimeout = Duration(seconds: 5);

  Timer? _timer;

  /// Bumped on dispose; an in-flight fix from an older generation discards its
  /// result instead of writing to dead state. (The `PresenceInteractor` idiom,
  /// verbatim.)
  int _generation = 0;

  @override
  MotionState build() {
    // Cancel the timer ONLY — never write state from a dispose callback
    // (Riverpod forbids it, and there is nothing left to render anyway).
    ref.onDispose(() {
      _generation++;
      _timer?.cancel();
      _timer = null;
    });

    _timer = Timer.periodic(cadence, (_) => unawaited(_tick(_generation)));
    // Immediately, not in 3 seconds. A runner that mounts mid-drive must not
    // spend its first tick claiming the driver is parked.
    unawaited(_tick(_generation));

    // 🔴 The honest starting position: NOT MOVING. We have not asked the device
    // anything yet, so we assert nothing — and asserting nothing means leaving
    // every control exactly where it is.
    return const MotionState();
  }

  Future<void> _tick(int gen) async {
    final fix = await ref
        .read(driverLocationServiceProvider)
        .currentFix(timeout: fixTimeout);
    if (gen != _generation) return; // disposed mid-fix

    final speed = fix?.speedMps;

    // 🔴 IGNORANCE DEGRADES OPEN. No fix, no permission, or a platform that
    // answered `speedAccuracy: 0` — all three mean the same thing: WE DO NOT
    // KNOW. A driver stopped at a kerb who cannot type because a junk fix
    // claimed 40 mph is a driver we have broken.
    if (speed == null) {
      if (state.inMotion || state.speedMps != null) {
        state = state.copyWith(inMotion: false, speedMps: null);
      }
      return;
    }

    final moving = state.inMotion
        // Latched ON: release only below the LOWER bar.
        ? speed > kMotionOffMps
        // Latched OFF: engage only above the UPPER bar.
        : speed > kMotionOnMps;

    if (moving != state.inMotion || speed != state.speedMps) {
      state = state.copyWith(inMotion: moving, speedMps: speed);
    }
  }

  /// Drives exactly one poll. Test-only: the suite scripts fixes through this
  /// rather than racing a 3-second wall-clock timer.
  @visibleForTesting
  Future<void> debugTick() => _tick(_generation);
}
