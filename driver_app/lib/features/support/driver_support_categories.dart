/// The driver's support taxonomy — the `category` string on
/// `POST /me/support-tickets`. SINGLE SOURCE OF TRUTH.
///
/// ⚠️ The support-ticket `category` vocabulary is UNPUBLISHED (#75, relayed by
/// the rider's Phase 12). We do not know the legal values, whether an unknown
/// category is stored, dropped, or 400s, or whether ops can filter on it. We
/// send a plausible, stable string and we say nothing to the driver about what
/// it does — because we do not know.
///
/// This is a RELAY, not a degradation: nothing here silently fails. The ticket
/// itself is BOUND and a human reads it, and the driver's own words in the
/// `subject` and `body` carry the meaning regardless of what the server does
/// with `category`.
///
/// 🔴 [trip] IS LOAD-BEARING. Phase 4 builds the reachable "I'm stuck" exit for
/// a driver trapped at a no-show pickup — `PATCH /rides/:id/cancel` needs a
/// `reason_id` no endpoint lists (#1), so every driver cancel currently 400s and
/// a driver at a no-show pickup has NO EXIT AT ALL. That exit routes here, under
/// this category. Import it; do not hand-type the string. Two copies of a
/// load-bearing category WILL drift.
abstract final class DriverSupportCategories {
  // ---------------------------------------------------------------------
  // Wire values — exactly what goes into `category` on the POST body.
  // ---------------------------------------------------------------------

  /// Anything that does not fit the other categories.
  static const String general = 'general';

  /// Something went wrong on a trip. **The Phase-4 "I'm stuck" exit lands
  /// here** — a driver at a no-show pickup with no working cancel (#1).
  static const String trip = 'trip_issue';

  /// Pay, adjustments, a missing fare.
  static const String earnings = 'earnings';

  /// Licence, insurance, MOT — anything about a compliance document.
  static const String documents = 'documents';

  /// Login, profile, vehicle details.
  static const String account = 'account';

  /// The app itself misbehaved.
  static const String app = 'app';

  // ---------------------------------------------------------------------
  // Labels — the picker reads from here, never from a literal.
  // ---------------------------------------------------------------------

  /// Human-readable label for every wire value, in picker order.
  static const Map<String, String> labels = <String, String>{
    general: 'General',
    trip: 'A problem on a trip',
    earnings: 'Pay or earnings',
    documents: 'Documents',
    account: 'My account',
    app: 'App problem',
  };

  /// The wire values in picker order.
  static const List<String> values = <String>[
    general,
    trip,
    earnings,
    documents,
    account,
    app,
  ];

  /// The label for a wire value, falling back to the raw value if a future
  /// server-side category arrives that this client does not know about.
  static String labelFor(String value) => labels[value] ?? value;
}
