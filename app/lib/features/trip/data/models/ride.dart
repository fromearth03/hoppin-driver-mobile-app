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

/// Pickup, dropoff and the road-following polyline.
///
/// The payload also carries `waypoints`; this model deliberately has no
/// field for them. The app is single-stop by product decision, and a model
/// that cannot hold a third point cannot accidentally draw one.
class RideGeo {
  final GeoPoint pickup;
  final GeoPoint dropoff;
  final List<GeoPoint> route;

  const RideGeo({
    required this.pickup,
    required this.dropoff,
    this.route = const [],
  });

  factory RideGeo.fromJson(Map<String, dynamic> json) => RideGeo(
        pickup:
            GeoPoint.fromJson(Map<String, dynamic>.from(json['pickup'] as Map)),
        dropoff: GeoPoint.fromJson(
            Map<String, dynamic>.from(json['dropoff'] as Map)),
        route: ((json['route'] as List?) ?? const [])
            .map((e) => GeoPoint.fromJson(Map<String, dynamic>.from(e as Map)))
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
        'arrived' || 'waiting' => TripPhase.waiting,
        'in_progress' || 'started' || 'on_trip' => TripPhase.inTrip,
        'completed' => TripPhase.completed,
        'cancelled' || 'canceled' => TripPhase.cancelled,
        _ => TripPhase.headingToPickup,
      };

  bool get isFinished =>
      phase == TripPhase.completed || phase == TripPhase.cancelled;

  static DateTime? _time(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
        id: json['id'] as String,
        ref: json['ref'] as String?,
        status: (json['status'] as String?) ?? '',
        geo: RideGeo.fromJson(Map<String, dynamic>.from(json['geo'] as Map)),
        rider: json['rider'] == null
            ? null
            : Rider.fromJson(Map<String, dynamic>.from(json['rider'] as Map)),
        chatUnread: (json['chat_unread'] as num?)?.toInt() ?? 0,
        pickupEtaSeconds: (json['pickup_eta_seconds'] as num?)?.toInt(),
        acceptedAt: _time(json['accepted_at']),
        arrivedAt: _time(json['arrived_at']),
        startedAt: _time(json['started_at']),
      );

  @override
  String toString() => 'Ride($id, $status)';
}
