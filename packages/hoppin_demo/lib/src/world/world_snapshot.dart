import 'dart:convert';

import 'package:hoppin_shared/hoppin_shared.dart';

import 'demo_world.dart';

/// A rider's star rating for one ride, held until the live API needs it.
typedef RatingEntry = ({int score, String? comments});

/// Versioned snapshot of one [DemoWorld] session — the F5-resume envelope.
///
/// A hand-written THIN codec: every model row round-trips through its own
/// generated `toJson`/`fromJson`, so the persisted shapes stay byte-identical
/// to what the screens consume; this class only adds the envelope (version,
/// seed, phase, timer remainders). [tryDecode] returns null on ANY parse,
/// type, or version failure — a corrupt snapshot always falls back to a
/// fresh seed, never a crash.
class WorldSnapshot {
  const WorldSnapshot({
    required this.seed,
    required this.scenario,
    required this.signedIn,
    required this.phase,
    required this.online,
    required this.liveRide,
    required this.sessionRides,
    required this.receipts,
    required this.transactions,
    required this.ratings,
    required this.savedLocations,
    required this.promo,
    required this.currentOffer,
    required this.liveRoute,
    required this.pendingRequest,
    required this.etaRemainingSeconds,
    required this.pendingTimerKind,
    required this.pendingTimerRemainingMs,
    required this.earningsPence,
    required this.tripCount,
    required this.onlineMs,
    required this.startedAtVirtualMs,
    required this.virtualMs,
    required this.idCounter,
  });

  /// Bumped whenever the envelope shape changes; a mismatch discards the
  /// snapshot (fresh seed) rather than guessing at migration.
  static const int codecVersion = 1;

  final int seed;
  final DemoScenario scenario;
  final bool signedIn;
  final WorldPhase phase;
  final bool online;
  final Ride? liveRide;
  final List<Ride> sessionRides;
  final Map<String, Receipt> receipts;
  final List<Transaction> transactions;
  final Map<String, RatingEntry> ratings;
  final List<SavedLocation> savedLocations;
  final PromoResult? promo;
  final RideOffer? currentOffer;
  final DemoRoute? liveRoute;
  final DemoRoute? pendingRequest;

  /// Clock-delta ETA at persist time (phase `accepted` only) — the restore
  /// re-derives `_etaStartedAt` from this so the countdown resumes mid-count.
  final int? etaRemainingSeconds;

  /// The single pending script timer (at most one is ever armed), persisted
  /// as its kind plus REMAINING duration so the restore re-arms the beat
  /// where it left off — never from the top.
  final ScriptTimerKind? pendingTimerKind;
  final int? pendingTimerRemainingMs;

  final int earningsPence;
  final int tripCount;
  final int onlineMs;

  /// Trip start as milliseconds past the seed anchor (virtual time), so the
  /// resumed receipt's pickup timestamp matches the original run.
  final int? startedAtVirtualMs;

  /// Elapsed virtual milliseconds at persist time — restored worlds keep
  /// deriving data timestamps forward from where the run had reached.
  final int virtualMs;

  /// The deterministic id counter, restored so post-resume rows can never
  /// collide with ids minted before the reload.
  final int idCounter;

  /// The JSON string [SnapshotStore.write] persists.
  String encode() => jsonEncode({
    'version': codecVersion,
    'seed': seed,
    'scenario': scenario.name,
    'signedIn': signedIn,
    'phase': phase.name,
    'online': online,
    'liveRide': liveRide?.toJson(),
    'sessionRides': [for (final ride in sessionRides) ride.toJson()],
    'receipts': {
      for (final entry in receipts.entries) entry.key: entry.value.toJson(),
    },
    'transactions': [for (final row in transactions) row.toJson()],
    'ratings': {
      for (final entry in ratings.entries)
        entry.key: {
          'score': entry.value.score,
          'comments': entry.value.comments,
        },
    },
    'savedLocations': [for (final row in savedLocations) row.toJson()],
    'promo': promo?.toJson(),
    'currentOffer': currentOffer?.toJson(),
    'liveRoute': _routeToJson(liveRoute),
    'pendingRequest': _routeToJson(pendingRequest),
    'etaRemainingSeconds': etaRemainingSeconds,
    'pendingTimer': pendingTimerKind == null
        ? null
        : {
            'kind': pendingTimerKind!.name,
            'remainingMs': pendingTimerRemainingMs ?? 0,
          },
    'earningsPence': earningsPence,
    'tripCount': tripCount,
    'onlineMs': onlineMs,
    'startedAtVirtualMs': startedAtVirtualMs,
    'virtualMs': virtualMs,
    'idCounter': idCounter,
  });

  /// Decodes a persisted snapshot; null when [raw] is missing, malformed,
  /// or written by a different codec version.
  static WorldSnapshot? tryDecode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      if (json['version'] != codecVersion) return null;
      final pendingTimer = json['pendingTimer'] as Map<String, dynamic>?;
      return WorldSnapshot(
        seed: json['seed'] as int,
        scenario: DemoScenario.values.byName(json['scenario'] as String),
        signedIn: json['signedIn'] as bool,
        phase: WorldPhase.values.byName(json['phase'] as String),
        online: json['online'] as bool,
        liveRide: json['liveRide'] == null
            ? null
            : Ride.fromJson(json['liveRide'] as Map<String, dynamic>),
        sessionRides: [
          for (final ride in json['sessionRides'] as List)
            Ride.fromJson(ride as Map<String, dynamic>),
        ],
        receipts: {
          for (final entry
              in (json['receipts'] as Map<String, dynamic>).entries)
            entry.key: Receipt.fromJson(entry.value as Map<String, dynamic>),
        },
        transactions: [
          for (final row in json['transactions'] as List)
            Transaction.fromJson(row as Map<String, dynamic>),
        ],
        ratings: {
          for (final entry in (json['ratings'] as Map<String, dynamic>).entries)
            entry.key: (
              score: (entry.value as Map<String, dynamic>)['score'] as int,
              comments:
                  (entry.value as Map<String, dynamic>)['comments'] as String?,
            ),
        },
        savedLocations: [
          for (final row in json['savedLocations'] as List)
            SavedLocation.fromJson(row as Map<String, dynamic>),
        ],
        promo: json['promo'] == null
            ? null
            : PromoResult.fromJson(json['promo'] as Map<String, dynamic>),
        currentOffer: json['currentOffer'] == null
            ? null
            : RideOffer.fromJson(json['currentOffer'] as Map<String, dynamic>),
        liveRoute: _routeFromJson(json['liveRoute']),
        pendingRequest: _routeFromJson(json['pendingRequest']),
        etaRemainingSeconds: json['etaRemainingSeconds'] as int?,
        pendingTimerKind: pendingTimer == null
            ? null
            : ScriptTimerKind.values.byName(pendingTimer['kind'] as String),
        pendingTimerRemainingMs: pendingTimer == null
            ? null
            : pendingTimer['remainingMs'] as int,
        earningsPence: json['earningsPence'] as int,
        tripCount: json['tripCount'] as int,
        onlineMs: json['onlineMs'] as int,
        startedAtVirtualMs: json['startedAtVirtualMs'] as int?,
        virtualMs: json['virtualMs'] as int,
        idCounter: json['idCounter'] as int,
      );
    } catch (_) {
      // Any malformed field means the whole snapshot is untrusted.
      return null;
    }
  }

  static Map<String, double>? _routeToJson(DemoRoute? route) => route == null
      ? null
      : {
          'pickupLat': route.pickupLat,
          'pickupLng': route.pickupLng,
          'dropoffLat': route.dropoffLat,
          'dropoffLng': route.dropoffLng,
        };

  static DemoRoute? _routeFromJson(Object? json) {
    if (json == null) return null;
    final map = json as Map<String, dynamic>;
    return (
      pickupLat: (map['pickupLat'] as num).toDouble(),
      pickupLng: (map['pickupLng'] as num).toDouble(),
      dropoffLat: (map['dropoffLat'] as num).toDouble(),
      dropoffLng: (map['dropoffLng'] as num).toDouble(),
    );
  }
}
