import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

import 'eligibility_builder.dart';
import 'eligibility_state.dart';

/// THE BRAIN of the eligibility riblet: the expiry ladder, computed off the
/// SERVER'S REAL `expires_at`, and the `403 NOT_ELIGIBLE` landing.
///
/// 🔴 THE TWO THINGS THIS EXISTS TO PREVENT.
///
/// **1. A driver learning their MOT expired by tapping GO and eating a 403.**
/// `GET /drivers/me/documents` is a **BOUND** endpoint that has always carried
/// a real `expires_at` per document, and nothing read it. A driver whose MOT
/// lapsed last Tuesday got up at 5am, drove to a rank, tapped GO, and got a red
/// banner — having burnt a morning on a problem the app could have named thirty
/// days earlier, on the home screen, by name.
///
/// **2. Guessing what `403 NOT_ELIGIBLE` means.** See [onNotEligible].
///
/// 🔴 THE DOUBLE READ IS DELIBERATE. LANE A (13-01) also reads
/// `GET /drivers/me/documents` through its own documents interactor. Both lanes
/// ship in the same wave and neither may depend on the other's files existing
/// at merge time, so this one does its own thin BOUND read. It costs one extra
/// GET on the dashboard and it bought three lanes that could not collide. A
/// follow-up dedupes the two reads behind one shared provider — that is a
/// follow-up, not a defect.
class EligibilityInteractor extends Notifier<EligibilityState> {
  /// The SERVER'S refusal, held OUTSIDE the ladder's own read.
  ///
  /// 🔴 A DOCUMENTS READ CANNOT CLEAR IT. `NOT_ELIGIBLE` also covers
  /// **restriction** and **suspension**, and neither of those shows up in
  /// `GET /drivers/me/documents` at all — so a perfectly clean read is not
  /// evidence the server would now let this driver in. Letting a clean read
  /// clear the refusal would tell a SUSPENDED driver everything is fine, which
  /// is the same guess this whole riblet exists to refuse. Only the SERVER may
  /// lift its own refusal — with a 200 on the next GO ([onEligible]).
  String? _refusedReason;
  bool _refused = false;

  @override
  EligibilityState build() {
    unawaited(refresh());
    return const EligibilityState();
  }

  /// Re-reads the BOUND `GET /drivers/me/documents` and recomputes the ladder.
  Future<void> refresh() async {
    try {
      final docs = await ref.read(driverRepositoryProvider).documents();
      final now = ref.read(nowProvider)();
      state = _compose(EligibilityPhase.known, _ladder(docs, now));
    } on Exception {
      // 🔴 A FAILED READ IS IGNORANCE, NOT INELIGIBILITY. Phase `unknown`, zero
      // rungs, `blocksGoOnline == false`, GO stays enabled. We could not read
      // their documents; that is OUR problem. The server re-checks at
      // go-online time and it is the authority — it will 403 if it must.
      //
      // A `catch` that disabled GO here would strand a perfectly legal driver
      // on a transient 500, and they would have no idea why.
      state = _compose(EligibilityPhase.unknown, const []);
    }
  }

  /// The SERVER let them in. Only a 200 on `POST /drivers/me/online` may lift a
  /// refusal the server itself issued — the app does not get to decide a
  /// refused driver has become eligible again because a read came back clean.
  void onEligible() {
    if (!_refused) return;
    _refused = false;
    _refusedReason = null;
    state = state.copyWith(
      phase: EligibilityPhase.known,
      notEligibleReason: null,
    );
  }

  /// The server's refusal, if any, always wins over what the ladder read.
  EligibilityState _compose(
    EligibilityPhase readPhase,
    List<DocumentExpiry> expiries,
  ) =>
      EligibilityState(
        phase: _refused ? EligibilityPhase.notEligible : readPhase,
        expiries: expiries,
        notEligibleReason: _refusedReason,
      );

  /// Records the SERVER'S OWN reason for a `403 NOT_ELIGIBLE`. Verbatim, or
  /// null.
  ///
  /// 🔴 NULL MEANS WE DO NOT KNOW, AND THE VIEW MUST SAY SO. It does NOT mean
  /// "documents". `NOT_ELIGIBLE` covers **compliance** OR **restriction** OR
  /// **suspension** — three completely different problems needing three
  /// completely different driver actions — and the server does not tell us
  /// which (the sub-code ask is relayed under #30).
  ///
  /// The instant this method starts synthesising a reason, the app is lying to
  /// a driver about why they cannot earn today. Point a SUSPENDED driver at
  /// their compliance paperwork and they will re-upload a licence that was
  /// never the problem, twice, and then ring support furious about the wrong
  /// thing — while the real problem goes untouched.
  ///
  /// (The tempting sentence is never spelled out literally here: the phase gate
  /// greps `lib/` for it, and a docstring EXPLAINING the prohibition must not
  /// be what trips the gate.)
  void onNotEligible(String? serverMessage) {
    _refused = true;
    _refusedReason =
        (serverMessage != null && serverMessage.trim().isNotEmpty)
            ? serverMessage
            : null; // ← honest null. NEVER a fallback sentence.
    state = state.copyWith(
      phase: EligibilityPhase.notEligible,
      notEligibleReason: _refusedReason,
    );
    // The ladder may have moved under them — re-read it. It cannot lift the
    // refusal (see [_refused]); it can only tell them more about what they can
    // see.
    unawaited(refresh());
  }

  /// Every document within 30 days of its server-issued expiry, worst first.
  List<DocumentExpiry> _ladder(List<DriverDocument> docs, DateTime now) {
    final out = <DocumentExpiry>[];
    for (final d in docs) {
      final at = d.expiresAt;
      // 🔴 NULL FIRST, EXPLICITLY, BEFORE ANY ARITHMETIC. A null `expires_at`
      // means this document does not expire (or the server did not tell us
      // when). It is NOT "expires today". Treating it as a date would disable a
      // working driver's GO button, forever, for a background check that was
      // never going to expire.
      if (at == null) continue;
      final rung = _rungFor(at, now);
      if (rung == null) continue; // >30 days out: silence. We do not nag.
      out.add(DocumentExpiry(
        documentType: d.documentType,
        label: kDriverDocumentLabels[d.documentType] ?? d.documentType,
        expiresAt: at,
        rung: rung,
      ));
    }
    // Worst first — the blocking rung leads, and every other one still shows.
    out.sort((a, b) => b.rung.index.compareTo(a.rung.index));
    return out;
  }

  /// Which rung [at] sits on relative to [now], or null when it is more than
  /// 30 days out (no rung at all — we do not nag a driver about a fine
  /// document).
  ///
  /// 🔴 ROUND TOWARD THE DRIVER, ALWAYS. Whole days, computed from the raw
  /// interval, so a document expiring "tomorrow at 09:00" read at 22:00 tonight
  /// is 11 hours away and is [ExpiryRung.lastDay] — not `expired`. Ambiguity
  /// favours their right to work.
  ExpiryRung? _rungFor(DateTime at, DateTime now) {
    final atUtc = at.toUtc();
    final nowUtc = now.toUtc();
    if (atUtc.isBefore(nowUtc)) return ExpiryRung.expired;
    final left = atUtc.difference(nowUtc);
    if (left <= const Duration(days: 1)) return ExpiryRung.lastDay;
    if (left <= const Duration(days: 7)) return ExpiryRung.prominent;
    if (left <= const Duration(days: 30)) return ExpiryRung.informational;
    return null;
  }
}
