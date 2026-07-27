import 'package:flutter/foundation.dart';

/// 🔴 THE INTERACTION BUDGET — AND IT IS NARROWER THAN INSTINCT SUGGESTS.
///
/// The offence in UK law is **HOLDING** the device. A cradled phone is legal,
/// and TOUCHING ITS SCREEN while cradled is **not** the offence; taxi and PHV
/// drivers are explicitly permitted cradled and hands-free use to accept
/// bookings and take calls. That is how every Uber, Bolt and FreeNow driver
/// legally taps Accept, Arrived and Start Trip — no special exemption was ever
/// needed, because mounted use was never the offence.
///
/// **So this flag DOES NOT BAN BUTTONS.** Banning them would force a driver to
/// pull over to do a thing the law lets them do at the wheel — less safe, not
/// more, and they would uninstall the app.
///
/// What it bans is **TYPING**. A driver can still be done for driving **without
/// due care** if an interaction distracts them, and for a PHV driver that feeds
/// the council's "fit and proper person" test. The constraint is
/// **glanceability**, and the least glanceable thing in any app is a keyboard.
/// Chat is templates-first precisely so the keyboard is never needed at speed.
@immutable
class MotionState {
  const MotionState({this.inMotion = false, this.speedMps});

  /// True while the vehicle is moving fast enough that TEXT ENTRY is a due-care
  /// hazard.
  ///
  /// Latches ON above [kMotionOnMps] and releases only below [kMotionOffMps].
  /// The hysteresis exists so a red light does not strobe the composer in and
  /// out of the tree — a control that appears and vanishes as the driver creeps
  /// forward is itself a distraction, and a worse one than either steady state.
  final bool inMotion;

  /// Last known speed in metres per second, or `null` when the platform gave us
  /// no confidence in its own number.
  ///
  /// 🔴 **NULL IS NOT ZERO.** Zero is "we know they are stopped". Null is "we
  /// do not know anything", and it is the reason [inMotion] degrades OPEN.
  final double? speedMps;

  static const Object _unset = Object();

  MotionState copyWith({bool? inMotion, Object? speedMps = _unset}) {
    return MotionState(
      inMotion: inMotion ?? this.inMotion,
      speedMps:
          identical(speedMps, _unset) ? this.speedMps : speedMps as double?,
    );
  }
}

/// 2.235 m/s ≈ **5 mph**. Above this the driver is DRIVING and the keyboard
/// goes away.
const double kMotionOnMps = 2.235;

/// 1.5 m/s ≈ **3.35 mph**. Only below this does the lock release.
///
/// The gap between this and [kMotionOnMps] is the hysteresis band: inside it,
/// the gate holds whatever it already was.
const double kMotionOffMps = 1.5;
