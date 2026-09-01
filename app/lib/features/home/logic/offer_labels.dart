import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';

import '../data/models/pending_offer.dart';

/// Fills in an offer's pickup/dropoff addresses when the service sends them
/// blank. Dispatch creates the ride from coordinates alone, and the backend
/// reverse-geocodes only on the post-accept endpoints — so a fresh offer
/// carries empty labels precisely when the driver most needs to know where
/// the job is. The platform geocoder (no API key, on-device) answers here.
///
/// Best-effort throughout: web has no platform geocoder, and a lookup can
/// fail offline — the offer then shows what the server sent, exactly as
/// before. Results are cached per offer so the 5-second poll never repeats
/// a lookup.
class OfferLabelResolver {
  final _cache = <String, ({String pickup, String dropoff})>{};

  /// Lazy: constructing the platform channel in tests throws, and an offer
  /// with server-sent labels never needs it at all.
  Geocoding? _geocoder;

  Future<PendingOffer> resolve(PendingOffer offer) async {
    final needsPickup = offer.pickupLabel.isEmpty && offer.pickup != null;
    final needsDropoff = offer.dropoffLabel.isEmpty && offer.dropoff != null;
    if (!needsPickup && !needsDropoff) return offer;
    if (kIsWeb) return offer;

    final cached = _cache[offer.id];
    if (cached != null) {
      return offer.withLabels(
        pickupLabel: needsPickup && cached.pickup.isNotEmpty ? cached.pickup : null,
        dropoffLabel:
            needsDropoff && cached.dropoff.isNotEmpty ? cached.dropoff : null,
      );
    }

    final pickup = needsPickup
        ? await _label(offer.pickup!.lat, offer.pickup!.lng)
        : '';
    final dropoff = needsDropoff
        ? await _label(offer.dropoff!.lat, offer.dropoff!.lng)
        : '';
    // Cache even a miss: a coordinate the geocoder cannot name now will not
    // name it on the next poll either, and retrying every 5s costs battery.
    _cache[offer.id] = (pickup: pickup, dropoff: dropoff);
    if (_cache.length > 16) _cache.remove(_cache.keys.first);

    return offer.withLabels(
      pickupLabel: pickup.isNotEmpty ? pickup : null,
      dropoffLabel: dropoff.isNotEmpty ? dropoff : null,
    );
  }

  Future<String> _label(double lat, double lng) async {
    try {
      final geocoder = _geocoder ??= Geocoding();
      final placemarks = await geocoder.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return '';
      final p = placemarks.first;
      final street = [p.subThoroughfare, p.thoroughfare]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(' ');
      final parts = [
        street.isNotEmpty ? street : (p.name ?? ''),
        p.locality ?? p.subAdministrativeArea ?? '',
      ].where((s) => s.isNotEmpty).toList();
      return parts.join(', ');
    } catch (_) {
      // No geocoder on this platform, or no network — blank is honest.
      return '';
    }
  }
}

final offerLabelResolverProvider =
    Provider<OfferLabelResolver>((ref) => OfferLabelResolver());
