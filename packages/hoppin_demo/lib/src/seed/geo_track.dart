/// Committed OSRM Wolverhampton geo-track (MAP-03) — the demo's spatial
/// ground truth for the driver approach and trip legs.
///
/// Provenance — fetched ONCE from the public OSRM demo server on 2026-07-08
/// (one dev-time request per leg, inside the demo server's reasonable-use
/// policy; the app itself NEVER calls OSRM):
///
///   curl "https://router.project-osrm.org/route/v1/driving/-2.1306,52.5903;-2.1200,52.5877?overview=full&geometries=geojson"
///   curl "https://router.project-osrm.org/route/v1/driving/-2.1200,52.5877;-2.0930,52.6046?overview=full&geometries=geojson"
///
/// Processing rule (reproducible): GeoJSON coordinates are `[lng, lat]` —
/// swapped on ingestion; consecutive duplicates dropped; downsampled to
/// >=20 m spacing keeping the first/last raw vertices; then the EXACT
/// scripted endpoint coords (DemoPlaces: Molineux spawn 52.5903,-2.1306 ·
/// Rail Station pickup 52.5877,-2.1200 · New Cross Hospital dropoff
/// 52.6046,-2.0930) replace a snapped endpoint within 1 m or are
/// prepended/appended otherwise, so pins and track endpoints coincide.
/// Cumulative meters (haversine, R=6371 km) and per-segment bearings were
/// computed offline at generation time and committed as const —
/// hoppin_demo imports NO map packages (no maplibre_gl, no latlong2).
library;

/// One vertex of a committed track leg.
class TrackPoint {
  const TrackPoint(this.lat, this.lng, this.cumulativeMeters, this.bearingDeg);

  final double lat;
  final double lng;

  /// Meters along the leg from its first point to this one (haversine,
  /// computed at generation time).
  final double cumulativeMeters;

  /// Compass bearing in degrees clockwise from north, `[0, 360)`, of the
  /// segment LEAVING this point; the last point repeats the previous
  /// segment's bearing.
  final double bearingDeg;
}

/// One ordered leg of the scripted route.
class TrackLeg {
  const TrackLeg(this.points);

  final List<TrackPoint> points;

  /// Total leg length in meters.
  double get lengthMeters => points.last.cumulativeMeters;
}

/// The two committed legs plus the pure interpolation the world's derived
/// getters ride on.
abstract final class GeoTrack {
  /// Driver spawn (Molineux Stadium) -> scripted pickup (Rail Station).
  static const TrackLeg approach = TrackLeg([
    TrackPoint(52.5903, -2.1306, 0.0, 326.7),
    TrackPoint(52.59093, -2.131282, 83.8, 349.6),
    TrackPoint(52.591129, -2.131342, 106.3, 248.8),
    TrackPoint(52.591054, -2.13166, 129.4, 207.6),
    TrackPoint(52.590827, -2.131855, 157.9, 186.7),
    TrackPoint(52.59051, -2.131916, 193.3, 188.5),
    TrackPoint(52.590035, -2.132033, 246.7, 192.8),
    TrackPoint(52.589704, -2.132157, 284.5, 193.2),
    TrackPoint(52.589439, -2.132259, 314.8, 191.9),
    TrackPoint(52.589196, -2.132343, 342.4, 194.0),
    TrackPoint(52.588916, -2.132458, 374.5, 183.0),
    TrackPoint(52.588565, -2.132488, 413.5, 188.6),
    TrackPoint(52.588363, -2.132538, 436.3, 184.0),
    TrackPoint(52.588091, -2.132569, 466.6, 141.7),
    TrackPoint(52.587944, -2.132378, 487.4, 81.0),
    TrackPoint(52.587987, -2.131932, 517.9, 73.5),
    TrackPoint(52.588178, -2.130871, 592.7, 65.4),
    TrackPoint(52.588315, -2.130379, 629.2, 57.8),
    TrackPoint(52.588497, -2.129903, 667.2, 57.0),
    TrackPoint(52.589013, -2.128595, 772.6, 61.2),
    TrackPoint(52.58918, -2.128094, 811.2, 72.9),
    TrackPoint(52.589283, -2.127542, 850.2, 80.2),
    TrackPoint(52.58933, -2.127093, 881.0, 84.9),
    TrackPoint(52.589352, -2.126686, 908.6, 87.5),
    TrackPoint(52.589364, -2.126226, 939.7, 90.6),
    TrackPoint(52.589361, -2.12575, 971.8, 95.3),
    TrackPoint(52.589343, -2.125433, 993.3, 99.6),
    TrackPoint(52.589302, -2.125032, 1020.8, 106.1),
    TrackPoint(52.589245, -2.124708, 1043.6, 112.4),
    TrackPoint(52.589126, -2.124232, 1078.4, 120.3),
    TrackPoint(52.58895, -2.123736, 1117.2, 123.7),
    TrackPoint(52.588812, -2.123395, 1144.8, 128.1),
    TrackPoint(52.5887, -2.12316, 1165.0, 143.2),
    TrackPoint(52.588466, -2.122872, 1197.5, 145.7),
    TrackPoint(52.588221, -2.122597, 1230.5, 148.7),
    TrackPoint(52.587971, -2.122347, 1263.0, 148.9),
    TrackPoint(52.58772, -2.122098, 1295.6, 157.7),
    TrackPoint(52.587435, -2.121906, 1329.8, 163.4),
    TrackPoint(52.586907, -2.121647, 1391.1, 163.3),
    TrackPoint(52.586586, -2.121488, 1428.4, 165.9),
    TrackPoint(52.586278, -2.121361, 1463.7, 159.2),
    TrackPoint(52.585906, -2.121129, 1507.9, 151.0),
    TrackPoint(52.58571, -2.12095, 1532.8, 130.3),
    TrackPoint(52.58558, -2.120698, 1555.2, 97.1),
    TrackPoint(52.585553, -2.120341, 1579.5, 25.8),
    TrackPoint(52.585891, -2.120072, 1621.2, 2.1),
    TrackPoint(52.586252, -2.12005, 1661.4, 26.3),
    TrackPoint(52.586465, -2.119877, 1687.8, 42.1),
    TrackPoint(52.586658, -2.11959, 1716.7, 16.1),
    TrackPoint(52.586854, -2.119497, 1739.4, 316.6),
    TrackPoint(52.587121, -2.119913, 1780.3, 31.0),
    TrackPoint(52.587226, -2.119809, 1793.9, 346.2),
    TrackPoint(52.5877, -2.12, 1848.2, 346.2),
  ]);

  /// Scripted pickup (Rail Station) -> dropoff (New Cross Hospital).
  static const TrackLeg trip = TrackLeg([
    TrackPoint(52.5877, -2.12, 0.0, 166.2),
    TrackPoint(52.587226, -2.119809, 54.3, 118.7),
    TrackPoint(52.587031, -2.119223, 99.4, 200.7),
    TrackPoint(52.586783, -2.119377, 128.9, 226.0),
    TrackPoint(52.586658, -2.11959, 148.9, 105.2),
    TrackPoint(52.586597, -2.119221, 174.7, 88.8),
    TrackPoint(52.586603, -2.118745, 206.9, 86.9),
    TrackPoint(52.586613, -2.118442, 227.4, 75.5),
    TrackPoint(52.586664, -2.118118, 250.0, 24.5),
    TrackPoint(52.587026, -2.117847, 294.2, 359.8),
    TrackPoint(52.587213, -2.117848, 315.0, 77.6),
    TrackPoint(52.587271, -2.117412, 345.2, 87.5),
    TrackPoint(52.587279, -2.11711, 365.6, 65.6),
    TrackPoint(52.587383, -2.116733, 393.6, 36.4),
    TrackPoint(52.587529, -2.116556, 413.7, 11.3),
    TrackPoint(52.587739, -2.116487, 437.5, 352.5),
    TrackPoint(52.588199, -2.116587, 489.1, 348.3),
    TrackPoint(52.588615, -2.116729, 536.4, 343.5),
    TrackPoint(52.588853, -2.116845, 564.0, 347.7),
    TrackPoint(52.589102, -2.116934, 592.3, 14.5),
    TrackPoint(52.58936, -2.116824, 621.9, 63.3),
    TrackPoint(52.58949, -2.116398, 654.1, 63.3),
    TrackPoint(52.5897, -2.11571, 706.1, 55.6),
    TrackPoint(52.589928, -2.115162, 751.0, 57.8),
    TrackPoint(52.590068, -2.114796, 780.2, 59.7),
    TrackPoint(52.590413, -2.113826, 856.2, 60.9),
    TrackPoint(52.590772, -2.112765, 938.2, 59.8),
    TrackPoint(52.591185, -2.111599, 1029.4, 58.0),
    TrackPoint(52.591417, -2.110988, 1078.0, 55.0),
    TrackPoint(52.591912, -2.109823, 1174.1, 52.3),
    TrackPoint(52.592279, -2.109042, 1240.8, 51.5),
    TrackPoint(52.592902, -2.107751, 1352.1, 61.2),
    TrackPoint(52.593129, -2.107071, 1404.6, 67.3),
    TrackPoint(52.593255, -2.106576, 1440.8, 75.5),
    TrackPoint(52.593313, -2.106207, 1466.6, 78.1),
    TrackPoint(52.593368, -2.105777, 1496.2, 83.6),
    TrackPoint(52.593406, -2.105221, 1534.0, 87.2),
    TrackPoint(52.593416, -2.10489, 1556.4, 90.4),
    TrackPoint(52.593414, -2.104369, 1591.6, 91.7),
    TrackPoint(52.5934, -2.103603, 1643.4, 92.8),
    TrackPoint(52.593382, -2.102987, 1685.0, 33.4),
    TrackPoint(52.593537, -2.102819, 1705.7, 348.4),
    TrackPoint(52.593748, -2.10289, 1729.6, 351.2),
    TrackPoint(52.594818, -2.103163, 1850.0, 40.5),
    TrackPoint(52.594984, -2.10293, 1874.3, 74.1),
    TrackPoint(52.595046, -2.102571, 1899.5, 23.9),
    TrackPoint(52.595425, -2.102295, 1945.6, 36.9),
    TrackPoint(52.59566, -2.102005, 1978.2, 352.3),
    TrackPoint(52.596105, -2.102104, 2028.2, 353.3),
    TrackPoint(52.596332, -2.102148, 2053.6, 358.2),
    TrackPoint(52.596562, -2.10216, 2079.2, 359.1),
    TrackPoint(52.596967, -2.10217, 2124.2, 354.8),
    TrackPoint(52.597195, -2.102204, 2149.7, 352.6),
    TrackPoint(52.597392, -2.102246, 2171.7, 353.3),
    TrackPoint(52.597636, -2.102293, 2199.1, 352.7),
    TrackPoint(52.598154, -2.102402, 2257.1, 349.6),
    TrackPoint(52.598587, -2.102533, 2306.1, 349.5),
    TrackPoint(52.598966, -2.102649, 2348.9, 350.2),
    TrackPoint(52.599287, -2.10274, 2385.2, 349.4),
    TrackPoint(52.599642, -2.102849, 2425.3, 346.8),
    TrackPoint(52.600174, -2.103055, 2486.1, 344.3),
    TrackPoint(52.600537, -2.103223, 2528.0, 349.5),
    TrackPoint(52.601, -2.103364, 2580.4, 349.6),
    TrackPoint(52.601681, -2.10357, 2657.4, 64.4),
    TrackPoint(52.601898, -2.102824, 2713.2, 65.7),
    TrackPoint(52.601987, -2.1025, 2737.2, 62.8),
    TrackPoint(52.602079, -2.102205, 2759.6, 59.2),
    TrackPoint(52.602206, -2.101854, 2787.2, 57.3),
    TrackPoint(52.602468, -2.101182, 2841.2, 58.6),
    TrackPoint(52.602632, -2.10074, 2876.1, 60.8),
    TrackPoint(52.602748, -2.100398, 2902.6, 63.3),
    TrackPoint(52.603018, -2.099515, 2969.4, 51.6),
    TrackPoint(52.603316, -2.098897, 3022.6, 52.0),
    TrackPoint(52.603442, -2.098631, 3045.4, 53.9),
    TrackPoint(52.603556, -2.098374, 3066.9, 54.3),
    TrackPoint(52.603938, -2.097499, 3139.7, 54.6),
    TrackPoint(52.60448, -2.096243, 3243.7, 56.5),
    TrackPoint(52.604991, -2.094971, 3346.7, 136.5),
    TrackPoint(52.604164, -2.09368, 3473.4, 45.6),
    TrackPoint(52.604549, -2.093033, 3534.6, 57.8),
    TrackPoint(52.604567, -2.092986, 3538.4, 345.6),
    TrackPoint(52.6046, -2.093, 3542.2, 345.6),
  ]);

  /// The position and heading at fraction [t] of [leg], travelled at
  /// constant speed along the route: [t] is clamped to `[0, 1]`, mapped
  /// linearly onto the cumulative-distance table, and lat/lng are linearly
  /// interpolated within the containing segment (exact enough at city
  /// scale). Returns the EXACT endpoint vertices at t=0 and t=1 so pins and
  /// parked cars coincide. Pure and synchronous — same inputs, same output.
  static (double lat, double lng, double bearingDeg) pointAlong(
    TrackLeg leg,
    double t,
  ) {
    final points = leg.points;
    final clamped = t.clamp(0.0, 1.0).toDouble();
    final target = clamped * leg.lengthMeters;
    var i = 0;
    while (i < points.length - 2 &&
        points[i + 1].cumulativeMeters < target) {
      i++;
    }
    final a = points[i];
    final b = points[i + 1];
    final span = b.cumulativeMeters - a.cumulativeMeters;
    final f = span <= 0
        ? 0.0
        : ((target - a.cumulativeMeters) / span).clamp(0.0, 1.0).toDouble();
    if (f <= 0) return (a.lat, a.lng, a.bearingDeg);
    if (f >= 1) return (b.lat, b.lng, a.bearingDeg);
    return (
      a.lat + (b.lat - a.lat) * f,
      a.lng + (b.lng - a.lng) * f,
      a.bearingDeg,
    );
  }
}
