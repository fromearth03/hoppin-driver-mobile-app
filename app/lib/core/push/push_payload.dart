enum PushType { rideOffer, complianceAppeal, rideUpdate, other }

/// The routable part of an FCM data payload.
///
/// Deliberately carries no fare, label or timing. The backend sends some of
/// those as best-effort context, but rendering them would let a stale push
/// contradict `GET /drivers/me/offers`. The push says "something happened";
/// the endpoint says what.
class PushPayload {
  final PushType type;
  final String? rideId;
  final String? offerId;
  final String? appealId;
  final String? deepLink;

  const PushPayload({
    required this.type,
    this.rideId,
    this.offerId,
    this.appealId,
    this.deepLink,
  });

  static PushPayload? parse(Map<String, dynamic> data) {
    final rawType = data['type'] as String?;
    if (rawType == null) return null;

    // The backend duplicates keys in both cases; snake_case is canonical.
    String? pick(String snake, String camel) =>
        (data[snake] ?? data[camel]) as String?;

    return PushPayload(
      type: switch (rawType) {
        'ride_offer' => PushType.rideOffer,
        'compliance_appeal' => PushType.complianceAppeal,
        'ride_update' => PushType.rideUpdate,
        _ => PushType.other,
      },
      rideId: pick('ride_id', 'rideId'),
      offerId: pick('offer_id', 'offerId'),
      appealId: pick('appeal_id', 'appealId'),
      deepLink: pick('deep_link', 'deepLink'),
    );
  }

  @override
  String toString() => 'PushPayload($type, ride=$rideId, offer=$offerId)';
}
