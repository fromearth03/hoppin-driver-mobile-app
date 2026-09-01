import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

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
  final Ref _ref;
  Timer? _timer;
  StreamSubscription<Position>? _stream;
  Position? _last;

  /// Bumped by every start/stop. start() awaits a permission dialog; a
  /// stop() issued while that dialog is open must win, not be overtaken
  /// when the driver finally answers it.
  int _epoch = 0;

  LocationReporter(this._ref);

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
    _stream?.cancel();
    try {
      // distanceFilter 0: every fix updates the cache, so the beat always
      // has something fresh even when the car is parked.
      _stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
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
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _beat());
    _beat();
    return true;
  }

  void stop() {
    _epoch++;
    _timer?.cancel();
    _timer = null;
    _stream?.cancel();
    _stream = null;
    _last = null;
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
    } catch (_) {
      // A network hiccup — the next tick retries.
    }
  }
}

final locationReporterProvider = Provider<LocationReporter>((ref) {
  final reporter = LocationReporter(ref);
  ref.onDispose(reporter.stop);
  return reporter;
});
