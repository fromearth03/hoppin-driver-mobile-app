import '../../../../core/money.dart';
import 'ride.dart';

/// One leg of a multi-stop ride, as `GET /rides/:id/stops` returns it.
///
/// A "stop" here is really a leg *and* its destination: `seq` indexes the leg,
/// and the fare is what that leg earned. `kind` separates the intermediate
/// stops a driver waits at from the final dropoff, which has no waiting.
///
/// Field names are `RideStopRow`'s JSON tags in `multistop_repo.go`, which is
/// what the handler serialises straight into `stops[]`.
class RideStop {
  final int seq;

  /// `stop` or `dropoff`. Only `stop` accepts arrive/depart — the repository
  /// filters on `kind = 'stop'`, so calling them on the dropoff leg updates
  /// nothing and silently returns a zero wait.
  final String kind;
  final String label;
  final GeoPoint from;
  final GeoPoint to;
  final double distanceMeters;
  final double durationSeconds;

  /// What this leg earned. The platform's commission and levy are NOT taken
  /// out of this — they apply once, to the grand total, at settlement.
  final Pence fare;

  final int waitingSeconds;

  /// The wait actually charged at this stop. Zero inside the free grace.
  /// The grace and the per-minute rate live in the `multistop_config` table
  /// and are not exposed by any endpoint, so the app can only ever report
  /// this number — never predict it.
  final Pence waiting;

  final DateTime? arrivedAt;
  final DateTime? departedAt;

  /// True when the stop was added after the trip began, which is why a
  /// driver may see a leg they did not agree to at accept.
  final bool addedMidTrip;

  const RideStop({
    required this.seq,
    required this.kind,
    required this.label,
    required this.from,
    required this.to,
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.fare = const Pence(0),
    this.waitingSeconds = 0,
    this.waiting = const Pence(0),
    this.arrivedAt,
    this.departedAt,
    this.addedMidTrip = false,
  });

  bool get isDropoff => kind == 'dropoff';

  /// Waiting is only ever charged at an intermediate stop.
  bool get canWait => !isDropoff;

  /// The driver has arrived and not yet left: the wait clock is running.
  bool get isWaiting => arrivedAt != null && departedAt == null;

  bool get isDone => departedAt != null;

  /// "1.4 mi" — miles, as the rest of the app prints distance.
  String get distanceLabel {
    final miles = distanceMeters / 1609.344;
    if (miles >= 0.1) return '${miles.toStringAsFixed(1)} mi';
    return '${(distanceMeters * 3.28084).round()} ft';
  }

  static DateTime? _time(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  factory RideStop.fromJson(Map<String, dynamic> json) {
    double num_(String key) => (json[key] as num?)?.toDouble() ?? 0;
    int int_(String key) => (json[key] as num?)?.toInt() ?? 0;

    return RideStop(
      seq: int_('seq'),
      kind: (json['kind'] as String?) ?? 'stop',
      label: (json['label'] as String?) ?? '',
      from: GeoPoint(lat: num_('from_lat'), lng: num_('from_lng')),
      to: GeoPoint(lat: num_('to_lat'), lng: num_('to_lng')),
      distanceMeters: num_('distance_meters'),
      durationSeconds: num_('duration_seconds'),
      fare: Pence(int_('fare_pence')),
      waitingSeconds: int_('waiting_seconds'),
      waiting: Pence(int_('waiting_pence')),
      // Postgres renders these with a space rather than a 'T' separator
      // (`arrived_at::text`), which `DateTime.tryParse` accepts.
      arrivedAt: _time(json['arrived_at']),
      departedAt: _time(json['departed_at']),
      addedMidTrip: (json['added_mid_trip'] as bool?) ?? false,
    );
  }
}

/// The whole per-leg breakdown for a ride.
///
/// `multiStop` is false for an ordinary single-leg ride, where `stops` is
/// empty — the handler derives it from `len(stops) > 0`, so it is not a
/// separate claim we have to second-guess.
class RideStops {
  final bool multiStop;
  final List<RideStop> stops;
  final Pence legsTotal;
  final Pence waitingTotal;

  /// Legs plus waiting. The platform's cuts come off this once, at
  /// settlement — so this is the fare, not the driver's take-home.
  final Pence total;

  const RideStops({
    this.multiStop = false,
    this.stops = const [],
    this.legsTotal = const Pence(0),
    this.waitingTotal = const Pence(0),
    this.total = const Pence(0),
  });

  static const empty = RideStops();

  /// The intermediate stops only — what the driver actually waits at.
  List<RideStop> get waypoints => stops.where((s) => !s.isDropoff).toList();

  int get stopCount => waypoints.length;

  /// The stop the driver is currently sitting at, if any.
  RideStop? get waitingAt {
    for (final s in stops) {
      if (s.canWait && s.isWaiting) return s;
    }
    return null;
  }

  /// The next stop still to be served: the first intermediate stop the driver
  /// has not departed. Null once every stop is done and only the dropoff is
  /// left, which is when the trip becomes an ordinary single-leg run again.
  RideStop? get nextStop {
    for (final s in stops) {
      if (s.canWait && !s.isDone) return s;
    }
    return null;
  }

  factory RideStops.fromJson(Map<String, dynamic> json) {
    final rows = ((json['stops'] as List?) ?? const [])
        .map((e) => RideStop.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      // The query orders by seq, but the ordering is what every "next stop"
      // decision below rests on, so it is enforced here rather than trusted.
      ..sort((a, b) => a.seq.compareTo(b.seq));

    return RideStops(
      multiStop: (json['multi_stop'] as bool?) ?? rows.isNotEmpty,
      stops: rows,
      legsTotal: Pence((json['legs_total_pence'] as num?)?.toInt() ?? 0),
      waitingTotal: Pence((json['waiting_total_pence'] as num?)?.toInt() ?? 0),
      total: Pence((json['total_pence'] as num?)?.toInt() ?? 0),
    );
  }
}
