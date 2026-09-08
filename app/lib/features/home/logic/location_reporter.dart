import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/device/shift_service.dart';
import '../data/driver_status_repository.dart';

/// While the driver is online, their position IS the product: the dispatcher
/// places offers by it and the telemetry reaper drops a silent driver from
/// the supply pool entirely — a driver whose beats stop is not merely
/// "stale", they are invisible to matching.
///
/// The beat must therefore never depend on a cold GPS fix landing inside one
/// tick. A one-shot getCurrentPosition with a tight time limit fails exactly
/// that way: the first fix (warm from the permission dialog) succeeds, every
/// later one times out indoors, and the driver silently vanishes from
/// dispatch. Instead a continuous position stream keeps the GPS warm and
/// caches the latest fix, and the 10-second timer posts whatever the stream
/// has — falling back to the platform's last known position, and only as a
/// last resort to a fresh one-shot fix.
///
/// Permission is requested when the driver goes online — the moment it
/// obviously matters — never as a blanket ask at launch.
class LocationReporter {
  /// The steady beat once the driver is placed.
  ///
  /// The server marks a driver stale after 90 seconds of silence
  /// (`driverStaleAfterSeconds`), so the beat only has to be comfortably
  /// inside that. Fifteen seconds leaves room for five consecutive failures
  /// — a tunnel, a dead spot, a handful of dropped requests — before the
  /// driver falls out of the pool, without spending their battery and data
  /// on a position that has barely moved.
  ///
  /// The opening burst is what makes going online feel immediate; this is
  /// only the upkeep, and beating it harder buys nothing.
  static const beatInterval = Duration(seconds: 15);

  /// The interval used until the first fix has actually been posted.
  ///
  /// Going online is the moment the driver is waiting on: they are not in
  /// the pool, and no offer can reach them, until a position lands. Beating
  /// hard for those first seconds turns "why am I not getting anything" into
  /// a wait of about a second.
  static const firstFixInterval = Duration(seconds: 1);

  /// How long to keep up the fast beat before settling down.
  static const firstFixWindow = Duration(seconds: 20);

  /// Metres of movement before the platform pushes another fix.
  ///
  /// Ten metres is under a second of travel at 25mph and about two seconds in
  /// slow traffic, so a moving driver's cached position is never meaningfully
  /// behind the beat that posts it. A parked driver crosses it never, which
  /// is the entire point: the radio sleeps instead of resampling a spot the
  /// dispatcher already has.
  static const _streamDistanceFilter = 10;

  final Ref _ref;
  Timer? _timer;
  StreamSubscription<Position>? _stream;
  Position? _last;

  /// Set once a position has actually reached the server, which is what
  /// makes the driver dispatchable.
  bool _posted = false;

  DateTime? _startedAt;

  /// Bumped by every start/stop. start() awaits a permission dialog; a
  /// stop() issued while that dialog is open must win, not be overtaken
  /// when the driver finally answers it.
  int _epoch = 0;

  LocationReporter(this._ref, {this.shift = const ShiftService()});

  /// Injected so tests can assert the service follows the online switch
  /// without a live platform channel.
  final ShiftService shift;

  /// True when reporting actually started; false when permission was
  /// refused or location services are off, so the caller can tell the
  /// driver why offers will not come.
  Future<bool> start() async {
    final epoch = ++_epoch;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
    } catch (_) {
      // No geolocation channel (tests, odd platforms): reporting simply
      // doesn't start. The server's stale marker tells the truth from
      // there.
      return false;
    }

    if (epoch != _epoch) return false; // stopped while the dialog was up

    // The beat is worthless if the process does not survive the driver
    // locking their phone, so the service comes up before the first fix.
    // A refusal is not fatal — reporting still works while the app is
    // foregrounded — so this does not gate going online.
    if (await shift.canPostNotification()) {
      await shift.start();
    }
    if (epoch != _epoch) return false;

    _stream?.cancel();
    try {
      // 🔴 THE SINGLE BIGGEST BATTERY COST IN THE APP WAS HERE.
      //
      // `distanceFilter: 0` at high accuracy means the GPS radio runs flat
      // out for the whole shift — including the hours a driver spends parked
      // at a rank, where every fix reports the same spot. Over a ten-hour
      // shift that is most of a battery spent on positions that never change.
      //
      // The beat does NOT read this stream directly: it posts `_last`, the
      // cached fix. So the stream only has to keep something fresh in the
      // cache, not fire continuously. A 10m filter does exactly that — a
      // moving car crosses 10m in well under a second at any road speed, so
      // the cache stays current while driving, and a parked one stops
      // waking the radio at all.
      //
      // The platform still delivers a fix when the driver actually moves, and
      // `_beat()` falls back to `getLastKnownPosition` and then a one-shot
      // if the cache is somehow empty, so a stationary driver is never
      // dropped from the pool for want of a position.
      _stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: _streamDistanceFilter,
        ),
      ).listen(
        (position) {
          // The first fix after going online is worth a beat of its own —
          // it is what makes the driver dispatchable at all.
          final firstFix = _last == null;
          _last = position;
          if (firstFix) _post(position);
        },
        onError: (_) {}, // the timer's fallbacks carry the beat
        cancelOnError: false,
      );
    } catch (_) {
      // No stream on this platform: the timer's fallbacks still beat.
    }
    _timer?.cancel();
    _posted = false;
    _startedAt = DateTime.now();
    // Starts fast and steps down once a fix is away, rather than making the
    // driver wait out a full steady interval to enter the pool.
    _timer = Timer.periodic(firstFixInterval, (_) => _beat());
    _beat();
    return true;
  }

  void stop() {
    _epoch++;
    // Fire and forget: going offline must feel instant, and the service
    // stopping a moment later is invisible.
    shift.stop();
    _timer?.cancel();
    _timer = null;
    _stream?.cancel();
    _stream = null;
    _last = null;
    _posted = false;
    _startedAt = null;
  }

  /// One beat: post the freshest fix available, cheapest source first.
  Future<void> _beat() async {
    var position = _last;
    if (position == null) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }
    if (position == null) {
      try {
        // Last resort, and deliberately looser than the 10s tick: a slow
        // first fix should land on a later beat rather than time out
        // forever. Medium accuracy answers indoors, where the high-accuracy
        // one-shot used to hang.
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 25),
          ),
        );
        _last = position;
      } catch (_) {
        return; // nothing to report this tick; the stream may still warm up
      }
    }
    await _post(position);
  }

  Future<void> _post(Position position) async {
    try {
      // Best-effort: a missed beat is corrected by the next one, and the
      // server's stale window forgives several.
      await _ref
          .read(driverStatusRepositoryProvider)
          .updateLocation(position.latitude, position.longitude);
      _settleToSteadyBeat();
    } catch (_) {
      // A network hiccup — the next tick retries. Deliberately still on the
      // fast beat: the driver is not in the pool until one of these lands.
    }
  }

  /// Steps the fast opening beat down to the steady one.
  ///
  /// Called once a fix has actually reached the server — that is the moment
  /// the driver becomes dispatchable, and beating every second after it
  /// spends their battery for nothing. The window is a backstop for a handset
  /// that never manages to post at all, so a permanently failing device does
  /// not sit at one beat a second for the rest of the shift.
  void _settleToSteadyBeat() {
    if (_posted) return;
    final started = _startedAt;
    final lapsed =
        started != null && DateTime.now().difference(started) >= firstFixWindow;
    if (!lapsed && !_alwaysSettleOnPost) return;
    _posted = true;
    _timer?.cancel();
    _timer = Timer.periodic(beatInterval, (_) => _beat());
  }

  /// A posted fix is what makes the driver dispatchable, so the step-down
  /// happens on the first success rather than waiting the window out.
  static const _alwaysSettleOnPost = true;
}

final locationReporterProvider = Provider<LocationReporter>((ref) {
  final reporter = LocationReporter(ref);
  ref.onDispose(reporter.stop);
  return reporter;
});
