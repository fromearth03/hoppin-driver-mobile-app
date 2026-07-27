/// One autocomplete hit from `GET /geocode/search`.
///
/// `source` distinguishes where the hit came from: `saved` is one of the
/// caller's own saved places (the server always ranks these first), `map` is
/// the geocoder. The picker badges them differently so a rider can tell their
/// own "Home" from a street of the same name.
///
/// `postcode` is optional — Photon has one for most UK addresses but not all,
/// and a missing postcode must never suppress a result. `label` is always
/// present and is the only field safe to display.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.label,
    required this.lat,
    required this.lng,
    this.postcode,
    this.source = 'map',
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      label: (json['label'] as String?)?.trim() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      postcode: (json['postcode'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['postcode'] as String).trim(),
      source: (json['source'] as String?)?.trim().isEmpty ?? true
          ? 'map'
          : (json['source'] as String).trim(),
    );
  }

  final String label;
  final double lat;
  final double lng;
  final String? postcode;

  /// `saved` | `map`. Unknown values are passed through rather than rejected —
  /// the server may add a source (e.g. `airport`) before the app ships again.
  final String source;

  /// True when this is one of the caller's own saved places.
  bool get isSaved => source == 'saved';

  Map<String, dynamic> toJson() => {
        'label': label,
        'lat': lat,
        'lng': lng,
        if (postcode != null) 'postcode': postcode,
        'source': source,
      };

  @override
  bool operator ==(Object other) =>
      other is PlaceSuggestion &&
      other.label == label &&
      other.lat == lat &&
      other.lng == lng &&
      other.postcode == postcode &&
      other.source == source;

  @override
  int get hashCode => Object.hash(label, lat, lng, postcode, source);
}
