/// BOOK-07 — the client geofence pre-flight.
///
/// Fast point-in-polygon before any booking network call. The server
/// `422 OUTSIDE_SERVICE_AREA` / `GET /service-areas/check` remains the gate.
///
/// Rings come from live pricing zones (`GET /service-areas`) when the app has
/// hydrated them. Until then we fall back to the committed Wolverhampton
/// octagon so offline/first-launch still works.
library;

/// One vertex of the service-area boundary ring: `(lat, lng)`.
typedef ServiceAreaVertex = ({double lat, double lng});

/// Fallback Wolverhampton ring (disclosed-approximate). Used only when live
/// zone polygons have not been loaded yet.
const List<ServiceAreaVertex> kWolverhamptonBoundary = [
  (lat: 52.630, lng: -2.140), // N
  (lat: 52.625, lng: -2.075), // NE
  (lat: 52.595, lng: -2.050), // E
  (lat: 52.560, lng: -2.070), // SE
  (lat: 52.550, lng: -2.130), // S
  (lat: 52.558, lng: -2.185), // SW
  (lat: 52.590, lng: -2.200), // W
  (lat: 52.622, lng: -2.185), // NW
];

List<List<ServiceAreaVertex>> _liveRings = [];

/// True once [applyServiceAreaGeoJSON] installed at least one live ring.
bool get serviceAreasHydrated => _liveRings.isNotEmpty;

/// Replace the live coverage rings from `GET /service-areas` (`geom` GeoJSON).
void applyServiceAreaGeoJSON(Iterable<dynamic> areas) {
  final rings = <List<ServiceAreaVertex>>[];
  for (final raw in areas) {
    if (raw is! Map) continue;
    rings.addAll(_ringsFromGeom(raw['geom']));
  }
  if (rings.isNotEmpty) _liveRings = rings;
}

/// True when `(lat, lng)` falls inside any live zone, or the fallback octagon.
bool isInsideServiceArea(double lat, double lng) {
  final rings = _liveRings.isNotEmpty ? _liveRings : [kWolverhamptonBoundary];
  for (final ring in rings) {
    if (_pip(lat, lng, ring)) return true;
  }
  return false;
}

bool _pip(double lat, double lng, List<ServiceAreaVertex> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final yi = ring[i].lat, xi = ring[i].lng;
    final yj = ring[j].lat, xj = ring[j].lng;
    final crosses = (yi > lat) != (yj > lat) &&
        lng < (xj - xi) * (lat - yi) / (yj - yi) + xi;
    if (crosses) inside = !inside;
  }
  return inside;
}

List<List<ServiceAreaVertex>> _ringsFromGeom(dynamic geom) {
  if (geom == null) return const [];
  Map<String, dynamic>? g;
  if (geom is Map<String, dynamic>) {
    g = geom;
  } else if (geom is Map) {
    g = Map<String, dynamic>.from(geom);
  } else {
    return const [];
  }
  final type = g['type'] as String? ?? '';
  final coords = g['coordinates'];
  if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
    return [_ring(coords.first)];
  }
  if (type == 'MultiPolygon' && coords is List) {
    return [
      for (final poly in coords)
        if (poly is List && poly.isNotEmpty) _ring(poly.first),
    ];
  }
  return const [];
}

List<ServiceAreaVertex> _ring(dynamic ring) {
  if (ring is! List) return const [];
  final out = <ServiceAreaVertex>[];
  for (final p in ring) {
    if (p is! List || p.length < 2) continue;
    final lng = (p[0] as num).toDouble();
    final lat = (p[1] as num).toDouble();
    out.add((lat: lat, lng: lng));
  }
  if (out.length >= 2 &&
      out.first.lat == out.last.lat &&
      out.first.lng == out.last.lng) {
    out.removeLast();
  }
  return out.length >= 3 ? out : const [];
}
