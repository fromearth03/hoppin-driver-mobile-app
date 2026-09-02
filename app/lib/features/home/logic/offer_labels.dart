import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/geo/place_labeler.dart';
import '../../trip/data/trip_repository.dart';
import '../data/models/pending_offer.dart';

/// Fills in an offer's pickup/dropoff addresses when the service sends them
/// blank. Dispatch creates the ride from coordinates alone, and the backend
/// reverse-geocodes only on the post-accept endpoints — so a fresh offer
/// carries empty labels precisely when the driver most needs to know where
/// the job is. The shared [PlaceLabeler] answers on-device.
class OfferLabelResolver {
  final PlaceLabeler _labeler;
  final TripRepository _trips;

  /// One stops fetch per ride, remembered across the 5-second poll. An
  /// empty list is a real answer (single-leg ride) and is cached too.
  final _stops = <String, List<String>>{};

  OfferLabelResolver(this._labeler, this._trips);

  Future<PendingOffer> resolve(PendingOffer offer) async {
    var out = offer;

    final needsPickup = out.pickupLabel.isEmpty && out.pickup != null;
    final needsDropoff = out.dropoffLabel.isEmpty && out.dropoff != null;
    if (needsPickup || needsDropoff) {
      final pickup = needsPickup
          ? await _labeler.label(out.pickup!.lat, out.pickup!.lng)
          : '';
      final dropoff = needsDropoff
          ? await _labeler.label(out.dropoff!.lat, out.dropoff!.lng)
          : '';
      out = out.withLabels(
        pickupLabel: pickup.isNotEmpty ? pickup : null,
        dropoffLabel: dropoff.isNotEmpty ? dropoff : null,
      );
    }

    // Multi-stop shape: the driver is already a ride party at offer time,
    // so the stops read is authorized pre-accept. A job with a mid point
    // must show it BEFORE the driver commits.
    if (out.rideId.isNotEmpty) {
      var labels = _stops[out.rideId];
      if (labels == null) {
        final result = await _trips.stops(out.rideId);
        final stops = result.valueOrNull;
        if (stops != null) {
          labels = <String>[];
          for (final (i, stop) in stops.waypoints.indexed) {
            var label = stop.label;
            if (label.isEmpty) {
              label = await _labeler.label(stop.to.lat, stop.to.lng);
            }
            labels.add(label.isEmpty ? 'Stop ${i + 1}' : label);
          }
          _stops[out.rideId] = labels;
          if (_stops.length > 16) _stops.remove(_stops.keys.first);
        }
      }
      if (labels != null && labels.isNotEmpty) {
        out = out.withLabels(waypointLabels: labels);
      }
    }
    return out;
  }
}

final offerLabelResolverProvider = Provider<OfferLabelResolver>((ref) =>
    OfferLabelResolver(
        ref.watch(placeLabelerProvider), ref.watch(tripRepositoryProvider)));
