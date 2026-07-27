/// BOOK-07 — the client geofence pre-flight.
///
/// A pure, dependency-free point-in-polygon test over the committed
/// Wolverhampton licensing boundary. It answers a single question honestly
/// and fast, before any network call: is this pickup even inside the area we
/// serve? The server `422 OUTSIDE_SERVICE_AREA` remains the enforcement
/// authority — this is a UX nicety and an audit-log hook, not the gate.
///
/// This file is PURE Dart: no Flutter imports, no I/O. Mirrors how the OSRM
/// demo track was committed as a const (06-01).
library;

/// One vertex of the service-area boundary ring: `(lat, lng)`.
typedef ServiceAreaVertex = ({double lat, double lng});

/// The Wolverhampton licensing-boundary ring, as committed const geometry.
///
/// DISCLOSED-APPROXIMATE — this is a coarse but plausible ring around the
/// Wolverhampton service area (lat ~52.55–52.63, lng ~-2.05 to -2.20), not the
/// authoritative licensing polygon. The real boundary coordinates are a small
/// backend/ops ask (09-RESEARCH Open Question 2); the convergence plan (09-05)
/// records the ask in SCOPE-TRACE + DOCS/06. Because the server `422` stays the
/// authority, an approximate client boundary is safe: worst case the pre-flight
/// lets an edge request through and the server declines it honestly.
///
/// Vertices are ordered around the ring (a simple, non-self-intersecting
/// octagon comfortably enclosing every seeded Wolverhampton landmark while
/// excluding Birmingham to the south-east).
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

/// True when `(lat, lng)` falls inside [kWolverhamptonBoundary].
///
/// Standard ray-casting (even-odd) point-in-polygon: cast a ray east from the
/// point and count boundary crossings — odd means inside. ~15 lines, no
/// dependencies, appropriate here (09-RESEARCH Pattern 4 / Don't-Hand-Roll
/// explicitly permits this one).
bool isInsideServiceArea(double lat, double lng) {
  final ring = kWolverhamptonBoundary;
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
