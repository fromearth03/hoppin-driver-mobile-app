/// Presence as the dispatcher sees it. `stale` means the driver is marked
/// online but their GPS has not reported inside `staleAfterSeconds` — they
/// will not be dispatched, and the UI must say so.
enum Presence { online, stale, offline }

class DriverStatus {
  final Presence presence;
  final DateTime? lastLocationAt;
  final int staleAfterSeconds;
  final bool dispatchable;

  /// One of the 11 shared eligibility tokens, or null when clear.
  final String? blockedReason;

  /// Present only for DOCS_* reasons. Every document standing in the way,
  /// so the driver can clear them in one sitting rather than one at a time.
  final List<String> blockingDocumentTypes;

  final String? activeRideId;

  const DriverStatus({
    required this.presence,
    required this.staleAfterSeconds,
    required this.dispatchable,
    this.lastLocationAt,
    this.blockedReason,
    this.blockingDocumentTypes = const [],
    this.activeRideId,
  });

  bool get isBlocked => blockedReason != null;

  /// What Home assumes when `/status` cannot be reached at all.
  ///
  /// Offline is the only honest guess: whatever the server thinks, an app
  /// that cannot talk to it is not receiving offers. It is deliberately not
  /// blocked — nothing is known to be wrong with this driver, and inventing
  /// a blocker would send them off to fix paperwork that is in order.
  ///
  /// The alternative was rendering a full-screen error, which hid the very
  /// toggle that would have recovered the session.
  static const unreachable = DriverStatus(
    presence: Presence.offline,
    staleAfterSeconds: 90,
    dispatchable: false,
  );

  factory DriverStatus.fromJson(Map<String, dynamic> json) => DriverStatus(
        presence: switch (json['presence'] as String?) {
          'online' => Presence.online,
          'stale' => Presence.stale,
          // An unrecognised presence is treated as offline: the safe reading
          // is "not currently taking work", never a false online.
          _ => Presence.offline,
        },
        lastLocationAt: json['last_location_at'] == null
            ? null
            : DateTime.parse(json['last_location_at'] as String),
        staleAfterSeconds: (json['stale_after_seconds'] as num?)?.toInt() ?? 90,
        dispatchable: json['dispatchable'] as bool? ?? false,
        blockedReason: json['blocked_reason'] as String?,
        blockingDocumentTypes:
            ((json['blocking_document_types'] as List?) ?? const [])
                .map((e) => e as String)
                .toList(),
        activeRideId: json['active_ride_id'] as String?,
      );
}
