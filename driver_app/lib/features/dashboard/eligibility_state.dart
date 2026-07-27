import 'package:flutter/foundation.dart';

/// The eight compliance document types, in the words a DRIVER reads.
///
/// 🔴 `mot_certificate` IS A KEY, NOT A SENTENCE. A rung that renders the raw
/// backend key has named nothing — the whole point of the ladder is that the
/// driver knows WHICH of eight documents to go and fix, without tapping GO to
/// find out.
///
/// The keys are set-equal to `DriverRepository.documentTypes` and a test holds
/// that line: a document type the backend serves and this map does not know
/// would degrade to its raw key on the driver's home screen.
///
/// (LANE A/13-01 declares an equivalent map for the documents surface. That
/// duplication is DELIBERATE and known: the two lanes ship in the same wave and
/// neither may depend on the other's files existing at merge time. A follow-up
/// lifts one copy into `hoppin_shared`.)
const Map<String, String> kDriverDocumentLabels = {
  'dvla_license': 'DVLA driving licence',
  'wolverhampton_taxi_badge': 'Taxi badge',
  'nr3s_background_check': 'Background check',
  'right_to_work': 'Right to work',
  'mot_certificate': 'MOT certificate',
  'insurance_policy': 'Insurance policy',
  'v5c_logbook': 'V5C logbook',
  'caz_compliance_proof': 'Clean Air Zone proof',
};

/// How close a document is to killing this driver's shift.
///
/// The rungs are DELIBERATELY asymmetric: three of them are NOTICES and only
/// one BLOCKS. A driver on their last valid day can still legally work, and
/// taking that away from them costs them a real shift for no reason at all.
enum ExpiryRung {
  /// T-30d → T-8d. A quiet heads-up. Changes nothing.
  informational,

  /// T-7d → T-2d. Louder. Still changes nothing.
  prominent,

  /// T-1d / expires today. Unmissable — and GO STAYS ENABLED. They can legally
  /// work today, and the app does not get to take that day off them.
  lastDay,

  /// Past the server's `expires_at`. 🔴 The only rung that blocks GO.
  expired,
}

/// One document, its real server-issued expiry, and which rung it sits on.
@immutable
class DocumentExpiry {
  /// Creates a rung entry for one document.
  const DocumentExpiry({
    required this.documentType,
    required this.label,
    required this.expiresAt,
    required this.rung,
  });

  /// The backend key — `mot_certificate`. Never rendered.
  final String documentType;

  /// What the DRIVER reads — 'MOT certificate'.
  final String label;

  /// The SERVER'S date. Never computed, never guessed, never rounded.
  final DateTime expiresAt;

  /// Which rung of the ladder this document is on.
  final ExpiryRung rung;
}

/// Where the eligibility read currently stands.
enum EligibilityPhase {
  /// The documents read has not landed (or FAILED). We know NOTHING, and
  /// 🔴 we therefore block NOTHING. Ignorance is not evidence.
  unknown,

  /// The documents read landed. The ladder below is real.
  known,

  /// `POST /drivers/me/online` answered `403 NOT_ELIGIBLE`.
  notEligible,
}

/// Immutable snapshot of what the app knows about this driver's right to work
/// today — hand-rolled in the [DashboardState] style (riblet convention).
@immutable
class EligibilityState {
  /// Creates an eligibility snapshot. The default is honest ignorance.
  const EligibilityState({
    this.phase = EligibilityPhase.unknown,
    this.expiries = const [],
    this.notEligibleReason,
  });

  /// Whether the documents read has landed, failed, or been overruled by a 403.
  final EligibilityPhase phase;

  /// Every document within 30 days of its server-issued expiry, worst first.
  /// Documents with a null `expires_at` are absent entirely.
  final List<DocumentExpiry> expiries;

  /// 🔴 THE SERVER'S OWN MESSAGE, VERBATIM. Null means WE DO NOT KNOW — and the
  /// view must say exactly that.
  ///
  /// It does NOT mean "documents". `403 NOT_ELIGIBLE` covers compliance OR
  /// restriction OR suspension and the server does not tell us which (the
  /// sub-code ask is relayed under #30). The instant this field is allowed to
  /// hold a synthesised fallback sentence, the app is lying to a driver about
  /// why they cannot earn today.
  final String? notEligibleReason;

  /// 🔴 TRUE **ONLY** WHEN A DOCUMENT HAS ACTUALLY EXPIRED.
  ///
  /// Not when the read failed. Not when a document is on its last day. Not when
  /// `expires_at` was null. A driver's ability to earn is not something we take
  /// away on a maybe — and the SERVER is the authority regardless: it re-checks
  /// at `POST /drivers/me/online` and answers 403 if it must. This flag exists
  /// so a driver hears it from US, FIRST, BY NAME — never so we can
  /// second-guess the server.
  bool get blocksGoOnline =>
      expiries.any((e) => e.rung == ExpiryRung.expired);

  /// The documents that have actually expired — named, so the rung can say
  /// WHICH. "You can't go online" without a name has told the driver nothing.
  List<DocumentExpiry> get expiredDocuments =>
      expiries.where((e) => e.rung == ExpiryRung.expired).toList();

  static const Object _unset = Object();

  /// copyWith with explicit null-clearing for the nullable field: passing
  /// `null` clears, omitting keeps.
  EligibilityState copyWith({
    EligibilityPhase? phase,
    List<DocumentExpiry>? expiries,
    Object? notEligibleReason = _unset,
  }) {
    return EligibilityState(
      phase: phase ?? this.phase,
      expiries: expiries ?? this.expiries,
      notEligibleReason: identical(notEligibleReason, _unset)
          ? this.notEligibleReason
          : notEligibleReason as String?,
    );
  }
}
