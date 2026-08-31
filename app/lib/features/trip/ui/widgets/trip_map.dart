import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/colors.dart';
import '../../data/models/ride.dart';

/// Pickup, any intermediate stops, dropoff, and the route between them.
///
/// The polyline is the OSRM geometry the backend persisted at dispatch — the
/// same road route the fare was priced against. We never ask the Directions
/// API for our own, which would draw a line the driver was not paid for. On a
/// multi-stop ride the service stitches the legs into that one polyline, so
/// the whole journey is already in `route`.
class TripMap extends StatelessWidget {
  final RideGeo geo;

  /// Which end of the leg to centre on. Pickup while approaching, dropoff
  /// once the rider is aboard.
  final GeoPoint? target;

  /// False for a finished trip: where the driver is NOW is unrelated to a
  /// journey from last Tuesday, and the blue dot would imply otherwise.
  final bool showMyLocation;

  const TripMap(
      {super.key, required this.geo, this.target, this.showMyLocation = true});

  static const _padding = 0.005;

  /// Smallest box containing every point, with a margin so pins are not
  /// flush against the edge. Pure, so the framing is testable without a map.
  static LatLngBounds boundsFor(List<GeoPoint> points) {
    if (points.isEmpty) {
      // Wolverhampton, the operating area — a sane frame for a ride whose
      // geometry failed to persist.
      return LatLngBounds(
        southwest: const LatLng(52.57, -2.14),
        northeast: const LatLng(52.60, -2.10),
      );
    }
    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    final pad = points.length == 1 ? _padding : 0.0;
    return LatLngBounds(
      southwest: LatLng(minLat - pad, minLng - pad),
      northeast: LatLng(maxLat + pad, maxLng + pad),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centre = target ?? geo.pickup;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(centre.lat, centre.lng),
        zoom: 14,
      ),
      myLocationEnabled: showMyLocation,
      myLocationButtonEnabled: showMyLocation,
      zoomControlsEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(geo.pickup.lat, geo.pickup.lng),
          infoWindow: InfoWindow(title: geo.pickup.label ?? 'Pickup'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(geo.dropoff.lat, geo.dropoff.lng),
          infoWindow: InfoWindow(title: geo.dropoff.label ?? 'Dropoff'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
        // Intermediate stops, numbered in travel order so the driver can
        // match a pin to the leg list without reading labels.
        for (final (i, stop) in geo.waypoints.indexed)
          Marker(
            markerId: MarkerId('stop_$i'),
            position: LatLng(stop.lat, stop.lng),
            infoWindow:
                InfoWindow(title: stop.label ?? 'Stop ${i + 1}'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
          ),
      },
      polylines: {
        if (geo.route.isNotEmpty)
          Polyline(
            polylineId: const PolylineId('route'),
            points: geo.route.map((p) => LatLng(p.lat, p.lng)).toList(),
            color: AppColors.primary,
            width: 5,
          ),
      },
      onMapCreated: (controller) {
        // Frame the route when we have one, but fall back to the stops
        // themselves: a multi-stop ride whose polyline failed to persist
        // would otherwise open zoomed on the pickup with the stops off
        // screen entirely.
        final frame = geo.route.length > 1 ? geo.route : geo.allPoints;
        if (frame.length > 1) {
          controller
              .animateCamera(CameraUpdate.newLatLngBounds(boundsFor(frame), 48));
        }
      },
    );
  }
}
