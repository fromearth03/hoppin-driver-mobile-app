import 'package:flutter/foundation.dart';

/// The current heading-home filter — the typed shape of
/// `GET /drivers/me/destination-filter`.
///
/// 🔴 EVERY NUMBER ON THIS OBJECT IS THE SERVER'S. NOT ONE IS OURS.
///
/// The backend already computes `daily_uses_remaining` and `expires_at` and
/// sends both. It owns the daily cap; it can change the cap tomorrow without
/// telling us. So there is **no default here, no fallback on the count, and no
/// client-side decrement anywhere in the app.** A client that invents "1 of 2
/// left" is telling a driver they may still set a filter on their way home — a
/// driver who then plans their evening around a use the server will refuse.
///
/// When [dailyUsesRemaining] is null the server did not send a count, so the
/// app HAS no count, and the UI says nothing at all about uses. Silence is the
/// honest answer to a question we cannot answer.
///
/// [active] false is the NORMAL state, not an error: it is what every driver
/// sees before they set one. It parses; it does not throw.
@immutable
class DestinationFilter {
  const DestinationFilter({
    required this.active,
    this.lat,
    this.lng,
    this.dailyUsesRemaining,
    this.expiresAt,
  });

  /// `{ "active": false }` — no filter is set. A fact, not a failure.
  const DestinationFilter.inactive() : this(active: false);

  /// Parses either branch of the contract, and degrades to [inactive] on
  /// anything it does not recognise.
  ///
  /// Every read is nullable and every read is defensive. A missing key produces
  /// `null` — never a default. If the payload is a shape the contract does not
  /// promise, the answer is "no filter", because IGNORANCE MUST DEGRADE TO
  /// KNOWING NOTHING, never to a confident wrong number.
  factory DestinationFilter.fromJson(Map<String, dynamic> json) {
    if (json['active'] != true) return const DestinationFilter.inactive();

    final filter = json['filter'];
    if (filter is! Map) return const DestinationFilter.inactive();

    return DestinationFilter(
      active: true,
      lat: (filter['lat'] as num?)?.toDouble(),
      lng: (filter['lng'] as num?)?.toDouble(),
      // No fallback. If the key is absent, this is null, and null is the truth.
      dailyUsesRemaining: (filter['daily_uses_remaining'] as num?)?.toInt(),
      expiresAt: switch (filter['expires_at']) {
        final String s => DateTime.tryParse(s)?.toUtc(),
        _ => null,
      },
    );
  }

  /// Whether a heading-home filter is currently set.
  final bool active;

  final double? lat;
  final double? lng;

  /// The server's OWN count. Null when the server did not send it — and when it
  /// is null the UI says NOTHING about uses, because we know nothing.
  final int? dailyUsesRemaining;

  /// The server's OWN expiry. Null when the server did not send it.
  final DateTime? expiresAt;
}
