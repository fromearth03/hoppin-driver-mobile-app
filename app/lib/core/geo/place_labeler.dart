import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

/// On-device reverse geocoding with a coordinate-keyed cache — the one
/// answer to every "the server sent coordinates but no address" gap: offer
/// pickup/dropoff, multi-stop legs, anywhere a driver needs a street name
/// the backend never wrote.
///
/// Best-effort throughout: web has no platform geocoder, lookups can fail
/// offline, and a miss is cached so a 5-second poll never repeats it.
class PlaceLabeler {
  final _cache = <String, String>{};

  /// Lazy: constructing the platform channel in tests throws, and callers
  /// with server-sent labels never need it at all.
  Geocoding? _geocoder;

  static String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';

  /// "12 High Street, Carlisle" — or '' when nothing can be resolved.
  Future<String> label(double lat, double lng) async {
    if (kIsWeb) return '';
    final key = _key(lat, lng);
    final hit = _cache[key];
    if (hit != null) return hit;

    var resolved = '';
    try {
      final geocoder = _geocoder ??= Geocoding();
      final placemarks = await geocoder.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final street = [p.subThoroughfare, p.thoroughfare]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' ');
        resolved = [
          street.isNotEmpty ? street : (p.name ?? ''),
          p.locality ?? p.subAdministrativeArea ?? '',
        ].where((s) => s.isNotEmpty).join(', ');
      }
    } catch (_) {
      // No geocoder on this platform, or no network — blank is honest.
    }
    // A miss is cached too: the coordinate will not name itself next poll,
    // and retrying every tick costs battery.
    _cache[key] = resolved;
    if (_cache.length > 64) _cache.remove(_cache.keys.first);
    return resolved;
  }
}

final placeLabelerProvider = Provider<PlaceLabeler>((ref) => PlaceLabeler());
