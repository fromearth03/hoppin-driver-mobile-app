import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/driver_status_repository.dart';

/// While the driver is online, their position IS the product: the dispatcher
/// places offers by it and marks a silent driver `stale` after 90 seconds.
/// Nothing in the app was reporting it — the "we can't see your location"
/// banner was the app warning about its own missing half.
///
/// Permission is requested when the driver goes online — the moment it
/// obviously matters — never as a blanket ask at launch.
class LocationReporter {
  final Ref _ref;
  Timer? _timer;

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
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _report());
    _report();
    return true;
  }

  void stop() {
    _epoch++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _report() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      // Best-effort: a missed beat is corrected by the next one, and the
      // server's stale window (90s) forgives several.
      await _ref
          .read(driverStatusRepositoryProvider)
          .updateLocation(position.latitude, position.longitude);
    } catch (_) {
      // GPS timeout or a web permission hiccup — the next tick retries.
    }
  }
}

final locationReporterProvider = Provider<LocationReporter>((ref) {
  final reporter = LocationReporter(ref);
  ref.onDispose(reporter.stop);
  return reporter;
});