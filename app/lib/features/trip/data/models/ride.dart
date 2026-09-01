/// Which screen the driver should be looking at. Derived from the server's
/// `status` on every read rather than advanced locally, so an admin
/// force-cancel or a transition made on another device lands correctly.
enum TripPhase { headingToPickup, waiting, inTrip, completed, cancelled }

class GeoPoint {
  final double lat;
  final double lng;
  final String? label;

  const GeoPoint({required this.lat, required this.lng, this.label});

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        label: json['label'] as String?,
      );
}

/// One turn-by-turn instruction from `geo.steps` on `GET /rides/:id`.
///
/// The service fills this only while the ride is accepted, arriving or
/// started (`rider_ride_detail.go` gates the OSRM `steps=true` call on those
/// statuses), so a finished trip's polls do not pay for a routing call. It is
/// `null` rather than `[]` whenever OSRM was slow or unavailable.
class NavStep {
  final String instruction;
  final double distanceMeters;
  final String maneuver;

  const NavStep({
    required this.instruction,
    this.distanceMeters = 0,
    this.maneuver = '',
  });

  factory NavStep.fromJson(Map<String, dynamic> json) => NavStep(
        instruction: (json['instruction'] as String?) ?? '',
        distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
        maneuver: (json['maneuver'] as String?) ?? '',
      );

  /// "1.5 mi" / "300 ft" — the units the design prints. Miles because this
  /// is a UK product and road signs are imperial.
  String get distanceLabel {
    final miles = distanceMeters / 1609.344;
    if (miles >= 0.1) return '${miles.toStringAsFixed(1)} mi';
    return '${(distanceMeters * 3.28084).round()} ft';
  }
}

/// Pickup, dropoff, any intermediate stops, and the road-following polyline.
///
/// `waypoints` is the ordered list of intermediate stops between pickup and
/// dropoff — empty on an ordinary single-leg ride. The per-leg fares and the
/// waiting clock do NOT live here; they come from `GET /rides/:id/stops`,
/// which is the only place the money is authoritative.
class RideGeo {
  final GeoPoint pickup;
  final GeoPoint dropoff;
  final List<GeoPoint> waypoints;
  final List<GeoPoint> route;
  final List<NavStep> steps;

  const RideGeo({
    required this.pickup,
    required this.dropoff,
    this.waypoints = const [],
    this.route = const [],
    this.steps = const [],
  });

  /// Every point the map should frame, in travel order.
  List<GeoPoint> get allPoints => [pickup, ...waypoints, dropoff];

  bool get isMultiStop => waypoints.isNotEmpty;

  factory RideGeo.fromJson(Map<String, dynamic> json) => RideGeo(
        pickup:
            GeoPoint.fromJson(Map<String, dynamic>.from(json['pickup'] as Map)),
        dropoff: GeoPoint.fromJson(
            Map<String, dynamic>.from(json['dropoff'] as Map)),
        waypoints: ((json['waypoints'] as List?) ?? const [])
            .map((e) => GeoPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        route: ((json['route'] as List?) ?? const [])
            .map((e) => GeoPoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        // Null when OSRM had nothing for us — an empty list is the right
        // reading, and the banner then renders nothing at all.
        steps: ((json['steps'] as List?) ?? const [])
            .map((e) => NavStep.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// The person being collected. Available only after acceptance — see the
/// offer card for why it is absent before.
class Rider {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final double? rating;
  final int ratingCount;
  final String? phone;

  const Rider({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.rating,
    this.ratingCount = 0,
    this.phone,
  });

  factory Rider.fromJson(Map<String, dynamic> json) => Rider(
        id: (json['id'] as String?) ?? '',
        fullName: (json['full_name'] ?? json['name'] ?? '') as String,
        avatarUrl: (json['avatar_url'] ?? json['photo_url']) as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
        phone: json['phone'] as String?,
      );
}

class Ride {
  final String id;
  final String? ref;
  final String status;
  final RideGeo geo;
  final Rider? rider;
  final int chatUnread;
  final int? pickupEtaSeconds;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;

  const Ride({
    required this.id,
    required this.status,
    required this.geo,
    this.ref,
    this.rider,
    this.chatUnread = 0,
    this.pickupEtaSeconds,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
  });

  /// The server's vocabulary mapped to ours. An unknown status falls back to
  /// the first phase rather than throwing — a driver mid-job must never see
  /// a crash because the backend added a state.
  TripPhase get phase => switch (status) {
        'accepted' ||
        'assigned' ||
        'driver_assigned' =>
          TripPhase.headingToPickup,
        // The service's own constant is `arriving` (models.StatusArriving);
        // missing it left the CTA on "Arrived at pickup" after a successful
        // arrive, and the second tap answered ILLEGAL_TRANSITION.
        'arriving' || 'arrived' || 'waiting' => TripPhase.waiting,
        'in_progress' || 'started' || 'on_trip' => TripPhase.inTrip,
        'completed' => TripPhase.completed,
        'cancelled' || 'canceled' => TripPhase.cancelled,
        _ => TripPhase.headingToPickup,
      };

  bool get isFinished =>
      phase == TripPhase.completed || phase == TripPhase.cancelled;

  /// `GET /rides/:id` carries no rider block — that identity lives only on
  /// `/rides/:id/rider-context`, so it is attached after the fact.
  Ride withRider(Rider? value) => Ride(
        id: id,
        status: status,
        geo: geo,
        ref: ref,
        rider: value ?? rider,
        chatUnread: chatUnread,
        pickupEtaSeconds: pickupEtaSeconds,
        acceptedAt: acceptedAt,
        arrivedAt: arrivedAt,
        startedAt: startedAt,
      );

  static DateTime? _time(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  factory Ride.fromJson(Map<String, dynamic> json) {
    // The service nests these under a `timestamps` block. Reading them at
    // the top level as well keeps the model working if that ever flattens,
    // and costs nothing.
    final times = (json['timestamps'] as Map?) ?? const {};
    DateTime? at(String key) => _time(times[key] ?? json[key]);

    // `geo` is a pointer server-side, so it can be absent. A hard cast here
    // would throw inside the repository and escape Result entirely, becoming
    // an unhandled async error rather than an Err the screen can render.
    final geo = json['geo'] as Map?;

    return Ride(
      id: json['id'] as String,
      ref: json['ref'] as String?,
      status: (json['status'] as String?) ?? '',
      geo: geo == null
          ? const RideGeo(
              pickup: GeoPoint(lat: 0, lng: 0),
              dropoff: GeoPoint(lat: 0, lng: 0),
            )
          : RideGeo.fromJson(Map<String, dynamic>.from(geo)),
      rider: json['rider'] == null
          ? null
          : Rider.fromJson(Map<String, dynamic>.from(json['rider'] as Map)),
      chatUnread: (json['chat_unread'] as num?)?.toInt() ?? 0,
      pickupEtaSeconds: (json['pickup_eta_seconds'] as num?)?.toInt(),
      acceptedAt: at('accepted_at'),
      arrivedAt: at('arrived_at'),
      startedAt: at('started_at'),
    );
  }

  @override
  String toString() => 'Ride($id, $status)';
}
