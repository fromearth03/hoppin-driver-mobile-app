/// A pickable point in the service area.
///
/// 🔴 WHY THIS IS A LIST AND NOT A SEARCH BOX.
///
/// **There is no geocoding endpoint (#35).** Nothing in `:8080` turns
/// "14 Broad Street" into a coordinate, and there is no third-party geocoder
/// wired into this app.
///
/// So a free-text address field on the destination filter would take a driver's
/// typing and have absolutely nothing to do with it. It would either silently
/// fail to resolve — leaving a driver who believes they set a filter and did
/// not — or it would need us to invent a coordinate, which is the same defect
/// wearing a different hat. **A box that silently fails to resolve is worse
/// than no box**, because the driver walks away believing the thing worked, and
/// drives home on a filter that was never set.
///
/// The list is honest: every entry has a REAL coordinate, and the driver can
/// see exactly what they are choosing. It body-swaps to place search the day a
/// geocoder exists, and nothing downstream changes — the filter takes `lat`/
/// `lng` either way.
///
/// 🔴 DO NOT ADD `fromAddress` / `search` / `geocode` HERE, not even a stub. A
/// stub is how a free-text box gets built on top of this in three weeks, and
/// the box would be a lie the moment it shipped.
class DriverPlace {
  const DriverPlace({required this.label, required this.lat, required this.lng});

  final String label;
  final double lat;
  final double lng;
}

/// The pickable destinations. Wolverhampton is the licensing authority and the
/// service area (`DOCS/04` — the compliance document vocabulary is literally
/// `wolverhampton_taxi_badge`).
///
/// The same six points the rider's picker offers, and deliberately the same
/// coordinates: `apps/driver` cannot import `apps/rider`, so this is a mirror,
/// not a fork. If one list gains a place, the other should too.
const driverPlaces = <DriverPlace>[
  DriverPlace(label: 'City Centre', lat: 52.5870, lng: -2.1288),
  DriverPlace(label: 'Wolverhampton Rail Station', lat: 52.5877, lng: -2.1200),
  DriverPlace(label: 'University of Wolverhampton', lat: 52.5896, lng: -2.1276),
  DriverPlace(label: 'New Cross Hospital', lat: 52.6046, lng: -2.0930),
  DriverPlace(label: 'Molineux Stadium', lat: 52.5903, lng: -2.1306),
  DriverPlace(label: 'Bentley Bridge Retail Park', lat: 52.6006, lng: -2.0868),
];
