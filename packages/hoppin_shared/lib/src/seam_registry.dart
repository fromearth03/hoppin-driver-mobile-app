/// DS-04 — the scope-trace enforcement registry.
///
/// One [SeamEntry] per scope-locked capability seam across BOTH app surfaces.
/// This is the machine-checkable half of the SCOPE-TRACE acceptance instrument:
/// the build fails (via `seam_registry_test.dart`) if a seam is not shaped as a
/// seam, if its `SEAM(#n)` tag points at a ledger location that does not
/// disclose THAT feature, or if its consumer renders a blank over `null`
/// instead of a designed unavailable-state.
///
/// ── v3.0 PHASE-0 RESTRUCTURE (2026-07-13) ────────────────────────────────
/// A gap is ONE fact. Its DISCLOSURE is per-surface.
///
/// The registry used to carry a single `app:` + `unavailableWidget:` pair on
/// each entry, which encoded the false assumption that exactly one app consumes
/// a gap. It does not hold: gap #41 (driver live position) blanks the RIDER's
/// live-tracking map AND the DRIVER's nav canvas; gap #17 (ride geometry) does
/// the same. Each surface owes its own honest state, in its own voice — the
/// rider's route-only rung says "we can't show your driver moving yet"; the
/// driver's would say "we can't show the map — here's the address". Those are
/// different products of the same gap, and a shared generic widget would make
/// the disclosure LESS honest, not more.
///
/// So: one gap, one ledger row, N [SeamDisclosure]s. Group C in each app asks
/// "does THIS app cover every disclosure it OWES?" — which is the question that
/// should always have been asked. The old shape is exactly why the driver's
/// consumption of #41/#17 was nobody's job for three phases.
///
/// The mapping is verified against `.planning/SCOPE-TRACE.md`:
///   - #41 "Live tracking"  → ledger row 11 (driverPosition seam).
///   - #46 "Promotions"     → ledger row 24 (pre-ride promo seam).
///   - #5  "driver-info"    → the "Also relayed (SEAMED)" summary line.
///   - #17 "ride-geo"       → the "Also relayed (SEAMED)" summary line.
/// NO seam binds to row 5 (that row is "Scheduled rides", an unrelated
/// feature) — a wrong-row binding must fail the ledger cross-check RED.
library;

/// What KIND of seam an entry is — this decides which enforcement groups
/// apply to it in `seam_registry_test.dart`.
enum SeamKind {
  /// A nullable capability seam on a repository — it MUST carry a `SEAM(#n)`
  /// source tag over a `Future<...?> async => null` method (group A applies) as
  /// well as the ledger + widget checks (groups B/C).
  repository,

  /// A view/gateway/data seam that lives OUTSIDE any repository — a gated SDK
  /// gateway (Stripe), a client geofence pre-flight, a client-only eligibility
  /// holder, a deep-link landing. It has no repository method, so group A
  /// (source-tag) does NOT apply; the ledger (B) + designed unavailable-state
  /// (C) checks still do.
  view,

  /// A DEVICE/OS capability gateway — GPS, camera, notification permission.
  ///
  /// Not a backend hole: there is no endpoint to ask for, and no gap to relay
  /// to the backend team. But the invariant is identical — a capability the app
  /// promises, which is unavailable, whose honest answer must be VISIBLE and
  /// REACHABLE. A driver whose OS location permission is denied cannot be
  /// dispatched (no heartbeat → the admin drops them in 5 minutes); the app
  /// must SAY SO rather than render a confident ONLINE state over a driver
  /// nobody can reach.
  ///
  /// Enforcement: no repository method (group A skips it, exactly as `view`);
  /// ledger (B) + designed-state (C) + live-reachability (D) all apply. It is
  /// EXCLUDED from the backend-gap relay checks — see [SeamEntry.isBackendGap].
  device,
}

/// How a scope-locked seam is classified in the SCOPE-TRACE ledger.
enum SeamState {
  /// Endpoint missing → nullable capability seam, graceful degrade, gap relayed.
  SEAMED,

  /// Endpoint exists but inert until a prereq (creds/config/SDK) lands.
  GATED,

  /// Scope mandates it, no endpoint at all (frontend-without-backend hole).
  MISSING_BE,

  /// Real endpoint exists and the frontend is wired to the live path.
  BOUND,
}

/// Which app surface renders a seam's designed unavailable-state.
///
/// Group C (the reachability check) is necessarily app-local: `apps/rider`
/// cannot import from `apps/driver`, so one builder map can never cover both.
/// This field lets each app's group C assert it covers EXACTLY the disclosures
/// it owes — no gaps, no orphans — which is what makes coverage provable
/// instead of incidental. Driver seams #6/#7 went unenforced for three phases
/// because nothing said which app owed them a disclosure.
enum SeamApp {
  /// The rider app renders this disclosure.
  rider,

  /// The driver app renders this disclosure.
  driver,
}

/// ONE app's designed answer to a seam.
///
/// A single backend gap can strand TWO surfaces. #41 (driver-location) blanks
/// the rider's live-tracking map AND the driver's nav canvas; each surface owes
/// its OWN honest state, in its own voice. **One gap, one ledger row, N
/// disclosures.**
///
/// A seam that is CONSUMED by an app's `lib/` but carries no [SeamDisclosure]
/// for that app is the blank-canvas defect — group B2 (consumption coverage,
/// in `hoppin_shared/test`) fails RED on exactly that.
class SeamDisclosure {
  /// Creates one app-surface disclosure for a seam.
  const SeamDisclosure({
    required this.app,
    required this.unavailableWidget,
    this.kind,
  });

  /// Which app renders [unavailableWidget].
  final SeamApp app;

  /// The name of the widget/state that renders this surface's designed
  /// unavailable-state (never a blank over `null`), e.g. "RouteOnlyMapState".
  final String unavailableWidget;

  /// OPTIONAL per-surface kind override.
  ///
  /// Almost always null — a gap's kind is a property of the gap, not the
  /// surface. It exists for the case where one surface consumes a seam through
  /// a repository method while another reaches the same gap through a view-only
  /// path (or vice versa), so the surface-appropriate enforcement group applies.
  /// When null, [SeamEntry.kind] governs.
  final SeamKind? kind;
}

/// One scope-locked capability seam: what it is, where the ledger discloses it,
/// and the designed fallback EACH consuming surface renders when it answers
/// `null`.
class SeamEntry {
  /// Creates a registry entry for a single seam.
  const SeamEntry({
    required this.gap,
    required this.feature,
    required this.ledgerRef,
    required this.state,
    required this.kind,
    required this.disclosures,
  });

  /// Which enforcement groups apply (see [SeamKind]).
  ///
  /// REQUIRED — deliberately not defaulted. It used to default to
  /// [SeamKind.repository], which meant a developer adding a seam outside
  /// `rides_repository.dart` got a confusing count-mismatch RED, and the path
  /// of least resistance was to mark it `view` and escape source enforcement
  /// entirely. Making it explicit forces the choice to be deliberate.
  final SeamKind kind;

  /// The backend-gap number this seam relays, e.g. `41` (rendered as `#41`
  /// both in the source `SEAM(#n)` tag and on the referenced ledger line).
  ///
  /// For [SeamKind.device] entries this is still a ledger row number — the
  /// device seam is ledgered like any other — but it is NOT a backend ask.
  /// See [isBackendGap].
  final int gap;

  /// A distinctive keyword that MUST appear on the referenced ledger line —
  /// the ledger cross-check (group B) matches this by name, not just by row
  /// number, so a wrong-row binding fails RED. e.g. "driver-info",
  /// "Live tracking", "Promotions", "ride-geo".
  final String feature;

  /// Where [feature] is disclosed in the ledger:
  ///   - "row:N"          → the ledger table row whose first cell is `| N |`.
  ///   - "relayed-seamed" → the "Also relayed" bullet beginning
  ///     "**SEAMED (promote when endpoint ships):**".
  final String ledgerRef;

  /// The ledger classification for this seam.
  final SeamState state;

  /// EVERY surface that consumes this seam and therefore owes a disclosure.
  ///
  /// A seam consumed by the driver but disclosed only by the rider is a blank
  /// canvas with a compliance badge — which is exactly what #41/#17 were until
  /// this milestone. Group B2 proves this list is complete against the actual
  /// call sites in each app's `lib/`.
  final List<SeamDisclosure> disclosures;

  /// True when this seam represents a BACKEND hole that must be relayed to the
  /// backend team. Device-capability seams ([SeamKind.device]) are not backend
  /// holes — there is nothing to ask the backend for — but they still owe a
  /// visible, reachable rung.
  bool get isBackendGap => kind != SeamKind.device;

  /// The disclosure this app owes, or null if this app does not consume the
  /// seam. Convenience for each app's group C.
  SeamDisclosure? disclosureFor(SeamApp app) {
    for (final d in disclosures) {
      if (d.app == app) return d;
    }
    return null;
  }

  /// Every app that owes a disclosure for this seam.
  Set<SeamApp> get apps => disclosures.map((d) => d.app).toSet();
}

/// Convenience: every disclosure owed by [app], paired with its seam.
Iterable<({SeamEntry entry, SeamDisclosure disclosure})> seamDisclosuresFor(
  SeamApp app,
) sync* {
  for (final entry in kSeamRegistry) {
    for (final d in entry.disclosures) {
      if (d.app == app) yield (entry: entry, disclosure: d);
    }
  }
}

/// ── GAP-NUMBER ALLOCATOR RANGES (parallel-milestone safety) ───────────────
///
/// Two milestones independently minting "the next number" is a guaranteed
/// collision — and a collision means group B binds a seam to the WRONG ledger
/// row, which is a SILENT failure of the honesty instrument (it does not fail
/// loudly; it just discloses a different feature than it claims to).
///
/// So the number spaces are DISJOINT and machine-checked
/// (`seam_registry_test.dart` → the gap-range guard):
///
///   Rider v2.0 (Phase 12) → **#70–#79**  · SCOPE-TRACE rows 30–49
///   Driver v3.0           → **#80–#99**  · SCOPE-TRACE rows 50+
///
/// Anything at or below #69 was minted before the split and is unconstrained.
const kGapRangeFloor = 70;

/// Rider v2.0's exclusive gap range (inclusive).
const kRiderGapRange = (min: 70, max: 79);

/// Driver v3.0's exclusive gap range (inclusive).
const kDriverGapRange = (min: 80, max: 99);

/// The scope-locked seams enforced by DS-04. The `SEAM(#n, …)` tags in the
/// repository sources must match the [SeamKind.repository] entries here exactly
/// (groups A/A0/B verify the binding both ways).
const kSeamRegistry = <SeamEntry>[
  // #5 driver-info — SEAMED: no driver-identity read on live.
  //
  // WAVE-0 CORRECTION (2026-07-12). This entry used to name `MatchedDriverCard`
  // — which is the POPULATED, CONFIDENT card that renders when the seam
  // ANSWERS. Group C therefore built it with a fabricated driver ("Gurpreet
  // Singh", 4.9★, plate BK72 WNH) and asserted the fake rendered: the test that
  // was supposed to prove "#5 degrades honestly" asserted the exact opposite of
  // the invariant. The real null-branch rung is `DriverUnavailableCard`
  // (trip_screen.dart:526,552) — an honest "details unavailable" state that
  // never fabricates an identity.
  SeamEntry(
    gap: 5,
    feature: 'driver-info',
    ledgerRef: 'relayed-seamed',
    state: SeamState.SEAMED,
    kind: SeamKind.repository,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'DriverUnavailableCard',
      ),
    ],
  ),
  SeamEntry(
    gap: 46,
    feature: 'Promotions',
    ledgerRef: 'row:24',
    state: SeamState.SEAMED,
    kind: SeamKind.repository,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'PromoUnavailableState',
      ),
    ],
  ),

  // #41 Live tracking — SEAMED: no rider-facing read of the driver's live
  // position (`POST /drivers/me/location` is write-only).
  //
  // v3.0 PHASE-0: this gap strands TWO surfaces, and until now only ONE was
  // disclosed.
  //   - RIDER  consumes it at `apps/rider/lib/features/trip/map/
  //            map_interactor.dart:106` → degrades to `RouteOnlyMapState`
  //            (route + pins, no fabricated car marker). Correct, and shipped.
  //   - DRIVER consumes it at `apps/driver/lib/features/trip/map/
  //            map_interactor.dart:92` AND `apps/driver/lib/features/
  //            offer_takeover/offer_takeover_interactor.dart:99` — and
  //            discloses NOTHING. `map_interactor.dart:116-119` collapses to
  //            `MapState()` → `MapPhase.hidden` → `map_view.dart:44` returns
  //            `SizedBox.shrink()`. The driver gets a BLANK CANVAS on every
  //            live trip: no map, no disclosure, no explanation.
  //
  // The driver disclosure named below (`DriverMapUnavailable`) DOES NOT EXIST
  // YET. **That RED is the deliverable of Phase 0** — it is the machine finally
  // saying out loud what has been true and unsaid for three phases. Phase 1
  // builds the widget and mounts it at `map_view.dart:44`.
  SeamEntry(
    gap: 41,
    feature: 'Live tracking',
    ledgerRef: 'row:11',
    state: SeamState.SEAMED,
    kind: SeamKind.repository,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'RouteOnlyMapState',
      ),
      SeamDisclosure(
        app: SeamApp.driver,
        unavailableWidget: 'DriverMapUnavailable',
      ),
    ],
  ),

  // #17 ride-geo — SEAMED: `GET /rides/:id` carries no pickup/dropoff
  // coordinates or route geometry.
  //
  // v3.0 PHASE-0: same two-surface story as #41. The rider degrades to
  // `RouteOnlyMapState`; the DRIVER consumes it at `apps/driver/lib/features/
  // trip/map/map_interactor.dart:98` and discloses nothing. Same blank canvas,
  // same missing rung, same intended RED.
  SeamEntry(
    gap: 17,
    feature: 'ride-geo',
    ledgerRef: 'relayed-seamed',
    state: SeamState.SEAMED,
    kind: SeamKind.repository,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'RouteOnlyMapState',
      ),
      SeamDisclosure(
        app: SeamApp.driver,
        unavailableWidget: 'DriverMapUnavailable',
      ),
    ],
  ),

  // ── Phase-9 view/gateway/data seams (kind: view — no repository method,
  //    so group A source-tag does NOT apply; ledger + widget checks do) ─────

  // Payments add-card is GATED on `503 PAYMENTS_DISABLED` until the Java
  // payment service + Stripe test secrets land (#64). The StripeSdkGateway
  // degrades to the designed ComingSoonSheet — never a fake success.
  SeamEntry(
    gap: 64,
    feature: 'add-card',
    ledgerRef: 'row:13',
    state: SeamState.GATED,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(app: SeamApp.rider, unavailableWidget: 'ComingSoonSheet'),
    ],
  ),

  // Client geofence pre-flight over the disclosed-approximate Wolverhampton
  // boundary (#63 — authoritative polygon is a backend/ops ask). Outside-area
  // pickups render the designed ServiceUnavailableScreen; server 422 authority.
  SeamEntry(
    gap: 63,
    feature: 'service area',
    ledgerRef: 'row:4',
    state: SeamState.SEAMED,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'ServiceUnavailableScreen',
      ),
    ],
  ),

  // 18+/DOB is collected at signup but has no rider-profile PATCH to persist
  // it (SL-5, #55) — MISSING_BE. The client holds it in SignupEligibility and
  // discloses the seam via the designed SignupEligibilityNotice state.
  SeamEntry(
    gap: 55,
    feature: '18+',
    ledgerRef: 'row:2',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'SignupEligibilityNotice',
      ),
    ],
  ),

  // Password-reset deep-link landing is GATED until the Supabase redirect
  // config lands (#49). ResetLandingScreen renders the honest unavailable
  // state — never a fake password form.
  SeamEntry(
    gap: 49,
    feature: 'reset',
    ledgerRef: 'row:21',
    state: SeamState.GATED,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'ResetLandingScreen',
      ),
    ],
  ),

  // ── Phase-10 view seams (booking/trip convergence — kind: view) ──────────

  // SL-1 ride-type selection (#65) — MISSING_BE: `:8080` exposes no
  // `GET /vehicle-categories` list. The static disclosed [Standard/XL/
  // Accessibility] selector IS the seam presentation (no invented live list);
  // the app already threads `vehicle_category_id`. Body-swap to the live list
  // with zero view change when the endpoint lands.
  SeamEntry(
    gap: 65,
    feature: 'ride-type',
    ledgerRef: 'row:6',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(app: SeamApp.rider, unavailableWidget: 'RideTypeSelector'),
    ],
  ),

  // SL-11 multi-stop (#59) — MISSING_BE: no waypoint fields on the
  // estimate/request/route contract, no Figma frame. The UI is DEFERRED
  // (locked decision 2); the designed MultiStopUnavailableNotice discloses it
  // honestly rather than shipping a waypoint editor the backend can't honour.
  SeamEntry(
    gap: 59,
    feature: 'Multi-stop',
    ledgerRef: 'row:7',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'MultiStopUnavailableNotice',
      ),
    ],
  ),

  // SL-9 pre-booking fee disclosure (#66) — MISSING_BE: no
  // `GET /me/cancellation-fee-schedule`. UNLIKE the other seams this one
  // RENDERS figures (the config-stub schedule, disclosed as indicative) — the
  // designed state is the fee disclosure WITH the number shown, never a blank
  // "coming soon" rung (Scope Lock §4.1 hard MUST). Body-swap to the live read.
  SeamEntry(
    gap: 66,
    feature: 'fee disclosure',
    ledgerRef: 'row:20',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(app: SeamApp.rider, unavailableWidget: 'FeeDisclosure'),
    ],
  ),

  // BOOK-08 auto no-driver retry (#67) — SEAMED: the backend owns the
  // automated re-dispatch; the client honestly presents the ongoing search via
  // MatchingRung ("finding another driver"), never a fake match. The NEW-driver
  // notification signal is SEAMED on the Phase-11 notification plumbing.
  SeamEntry(
    gap: 67,
    feature: 'finding another driver',
    ledgerRef: 'row:8',
    state: SeamState.SEAMED,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(app: SeamApp.rider, unavailableWidget: 'MatchingRung'),
    ],
  ),

  // ── Wave-0 (2026-07-12): the DRIVER-app seams that were shipping
  //    UNDISCLOSED. Group A previously scanned only `rides_repository.dart`,
  //    so these two sailed through three "green" phase gates with no tag, no
  //    entry, no ledger row and no designed rung. The closed-world check
  //    (group A0) now makes that impossible. ────────────────────────────────

  // #7 driver day stats — SEAMED: no driver-telemetry endpoint.
  // ROOT CAUSE of the Wave-0 live bug: the dashboard gated its online-state on
  // this null seam, so the GO button hung forever while the driver was already
  // in the dispatch pool. Presence is now authoritative from goOnline(); these
  // stats degrade to a designed "stats unavailable" rung over a working button.
  //
  // STILL LOAD-BEARING (v3.0 finding, D5): `payoutPence` and `activeRideId` are
  // BOTH sourced only from this null seam, so trip completion strands the driver
  // and a mid-trip refresh loses the trip. That violates the standing rule — a
  // capability seam may only feed DECORATION. Phase 1 decouples both.
  SeamEntry(
    gap: 7,
    feature: 'Driver day stats',
    ledgerRef: 'row:28',
    state: SeamState.SEAMED,
    kind: SeamKind.repository,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.driver,
        unavailableWidget: 'DriverStatsUnavailable',
      ),
    ],
  ),

  // #6 trip rider context — SEAMED: no rider-identity surface on the offer
  // payload. Degrades to pickup-pin-only (already correct in the view); this
  // entry makes the disclosure machine-enforced rather than incidental.
  SeamEntry(
    gap: 6,
    feature: 'Trip rider context',
    ledgerRef: 'row:29',
    state: SeamState.SEAMED,
    kind: SeamKind.repository,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.driver,
        unavailableWidget: 'RiderContextUnavailable',
      ),
    ],
  ),

  // ── Phase-11 view seams (notifications / comms / safety — kind: view) ────
  //
  // All three are RIDER view seams: no repository method answers null, so
  // group A (source-tag) does not apply. Group B (ledger) and group C
  // (REACHABILITY — the widget must be CONSTRUCTED in a real view) both do.
  // Each names its mount site below, because a widget nobody constructs is not
  // a disclosure — it is dead code wearing a compliance badge (Wave 0).

  // #45 masked in-trip voice call — MISSING_BE: there is no
  // `POST /rides/:id/call` proxy and no masked-number field on any ride
  // payload. The full Figma call surface (calling / ringing / connected) is
  // BUILT and REACHABLE at `/trip/:id/call` — and INERT. Zero SDK. No dial
  // scheme anywhere; an injectable UrlLauncher gateway is driven by a
  // recording fake across every control and records ZERO launches, so "the
  // app never dials" is a machine assertion, not a code-review promise. The
  // rung offers chat (BOUND) as the working alternative — a disclosure that
  // strands the rider is only half-honest.
  // MOUNT SITE: `call_screen.dart` constructs `CallUnavailableState`.
  //
  // v3.0 PHASE 4: the DRIVER now consumes this same gap, and the stake is
  // HIGHER on their side of the windscreen. The rider's rung says "we can't
  // connect you to your driver". The driver's says the true thing from the
  // other side: with no masked bridge, the only number a dial from the DRIVER
  // app could reach is the RIDER'S PERSONAL MOBILE — which a private-hire
  // driver must never hold and this app must never even possess.
  // `never_dial_test.dart` drives a recording UrlLauncher across every control
  // on every frame — including the driver-only INCOMING frame — and requires
  // zero launches. One gap, one ledger row, N disclosures.
  // DRIVER MOUNT SITE: `driver_call_screen.dart` constructs
  // `DriverCallUnavailableState` on every frame.
  SeamEntry(
    gap: 45,
    feature: 'voice call',
    ledgerRef: 'row:15',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'CallUnavailableState',
      ),
      SeamDisclosure(
        app: SeamApp.driver,
        unavailableWidget: 'DriverCallUnavailableState',
      ),
    ],
  ),

  // #57 revocable live-trip share URL — MISSING_BE: `POST /me/sos` takes
  // `live_share_url` as an INPUT, but nothing on the backend ISSUES or REVOKES
  // one. The designed Figma sheet plus the Scope-Lock-mandated revoke control
  // are BUILT and reachable from BOTH trip-screen share affordances; the link
  // field renders the rung where the URL would be. Never a fabricated URL,
  // never a clipboard write. (Wave 0 deleted a "copied" toast that copied a
  // sentence containing no link at all.)
  // MOUNT SITE: `share_trip_sheet.dart` constructs `ShareLinkUnavailableState`,
  // presented via `showShareTripSheet(` from `trip_screen.dart`.
  SeamEntry(
    gap: 57,
    feature: 'share',
    ledgerRef: 'row:18',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'ShareLinkUnavailableState',
      ),
    ],
  ),

  // #68 notification history — MISSING_BE: there is no `GET /me/notifications`
  // (nor mark-read / delete / delete-all). The centre is BUILT and reachable
  // from the shell bell at `/notifications`, fed by a session-local feed that
  // is deliberately NOT persisted — a local store pretending to be server
  // history would be fake-as-live. The rung discloses that older history
  // cannot be LOADED; it is never an empty-state falsely asserting "you have
  // no notifications", because asserting emptiness when the truth is ignorance
  // is precisely the quiet lie this phase exists to delete.
  // MOUNT SITE: `notification_centre_screen.dart` constructs
  // `NotificationHistoryUnavailable` (on the empty branch AND pinned beneath a
  // populated list — live events do not make OLDER history readable).
  SeamEntry(
    gap: 68,
    feature: 'Notification history',
    ledgerRef: 'row:26',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'NotificationHistoryUnavailable',
      ),
    ],
  ),

  // ══ RIDER v2.0 PHASE 12 — gap range #70–#79, SCOPE-TRACE rows 30–34 ═════
  //    Account, profile, support & compliance. ALL FIVE ARE `kind: view`:
  //    Phase 12 adds no repository seams and touches no repository file, so
  //    group A0's closed-world check stays green for free.
  //
  //    🔴 THESE FIVE WERE BUILT AND NEVER MINTED. Phase 12 shipped all five
  //    widgets and registered ZERO entries — and every enforcement group is a
  //    LOOP OVER THIS REGISTRY. Five unregistered seams contributed zero
  //    iterations, so the checks did not fail: THEY DID NOT RUN. The suite was
  //    green over five features it was not watching. A loop over minted gaps
  //    cannot see an unminted gap; that is why the registry is the instrument
  //    and not the report.

  // #70 personal information — MISSING_BE: there is no `GET`/`PATCH /me/profile`
  // (SL-5). The screen is built READ-ONLY over the four facts the session
  // genuinely holds — `fullName` / `email` / `phone?` / `createdAt` — and shows
  // nothing else. There is no City field and no avatar picker anywhere in the
  // product, so the Figma's "Wolverhampton, Eng" caption is a fabrication we
  // declined to draw. Save is VISIBLE and inert (`onPressed: null`); the rung
  // carries the one LIVE control on the screen — a working exit to `/support`,
  // which is the honest route to Art. 16 rectification while no PATCH exists.
  // MOUNT SITE: `personal_info_screen.dart` constructs `PersonalInfoUnavailable`
  // UNCONDITIONALLY, above the form — the seam is not sometimes-null, it is
  // always-null.
  SeamEntry(
    gap: 70,
    feature: 'personal information',
    ledgerRef: 'row:30',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'PersonalInfoUnavailable',
      ),
    ],
  ),

  // #71 settings preferences — MISSING_BE: there is no rider-preferences
  // endpoint. Seven switches render VISIBLE and inert (`onChanged: null`) under
  // ONE screen-level rung — one rung for the screen, not eight, because eight
  // identical rungs is noise and noise is how a disclosure gets ignored.
  //
  // The theme toggle is the ONE genuinely working control on the screen, and
  // the rung says so. It is also an ADDITION the Figma omits: ACCT-03 requires
  // it, so truth here meant adding a control, not only removing them.
  //
  // 🔴 "Require PIN for Payments" is OMITTED, not seamed. The Figma renders it
  // ON, for a PIN feature that DOES NOT EXIST — a toggle claiming payments are
  // PIN-protected is a SECURITY LIE, materially worse than a broken preference,
  // and there is no honest rung for it. You cannot disclose your way out of
  // telling someone their money is guarded when it is not.
  // MOUNT SITE: `settings_screen.dart` constructs `SettingsPrefsUnavailable`
  // ONCE, pinned above the toggle groups.
  SeamEntry(
    gap: 71,
    feature: 'settings preferences',
    ledgerRef: 'row:31',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'SettingsPrefsUnavailable',
      ),
    ],
  ),

  // #72 promo codes — MISSING_BE: there is no `GET /me/promos` (SL-13). Note
  // the asymmetry — `POST /rides/:id/promo` ALREADY WORKS, so a rider can
  // REDEEM a code they know; we simply cannot LIST the ones they hold.
  //
  // The screen is half-real and the split is VISIBLE: the banners section above
  // is BOUND (fed by the real `/ads` feed, with every `target_url` routed
  // through `isAllowlistedPushTarget()` — which closes the remaining half of
  // #36), and the codes section below is a permanent null.
  //
  // The rung says "we cannot LIST them" and NEVER "you have none." Asserting
  // emptiness when the truth is ignorance is the quiet lie this milestone
  // exists to delete. No invented codes: the Figma's `WELCOME20` / `REFER100` /
  // `Weekend Special` are all fabrications, and `REFER100` doubly so —
  // referrals are the owner's SOLE parked feature.
  // MOUNT SITE: `promotions_screen.dart` constructs `PromoCodesUnavailable` on
  // the codes section.
  SeamEntry(
    gap: 72,
    feature: 'promo codes',
    ledgerRef: 'row:32',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'PromoCodesUnavailable',
      ),
    ],
  ),

  // #73 account deletion — MISSING_BE (#43): `DELETE /me` does not exist.
  //
  // 🔴 READ THIS BEFORE YOU "FIX" THIS BUTTON. The STATE is MISSING_BE, but the
  // ACTION THE RIDER TAKES IS FULLY BOUND: the erasure request files a REAL
  // `POST /me/support-tickets` that lands in a real database that a real human
  // reads, against a real one-month statutory clock, with a named owner in
  // `DOCS/runbooks/data-rights-requests.md`. THIS IS THE ONLY SEAM IN THE
  // PROJECT WHERE THE RIDER'S NEED IS GENUINELY MET. Do NOT make this button
  // inert "for consistency" with the other rungs — that would take a working
  // Art. 17 route and break it.
  //
  // A manual erasure process is LAWFUL: GDPR mandates the outcome and the
  // deadline, not an automated endpoint. It is lawful ONLY IF THE RUNBOOK IS
  // OWNED — a deletion ticket nobody has been told to action is WORSE than an
  // inert button, because it manufactures the appearance of compliance.
  //
  // The rider is NOT signed out by this action. Signing them out would simulate
  // deletion and strand them outside the very ticket they need to follow.
  // Covers DATA-01 (Arts. 15/20 export) by the same mechanism.
  // MOUNT SITE: `delete_account_popup.dart` constructs `DeletionViaSupportNotice`,
  // presented via `showDeleteAccountPopup(` from `settings_screen.dart`.
  SeamEntry(
    gap: 73,
    feature: 'account deletion',
    ledgerRef: 'row:33',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'DeletionViaSupportNotice',
      ),
    ],
  ),

  // #74 consent record — MISSING_BE (#42): there is no `POST`/`GET /me/consents`.
  //
  // 🔴 #42 BLOCKS MARKETING SENDS. IT DOES NOT BLOCK RIDES. Ride processing
  // rests on the CONTRACT basis (Art. 6(1)(b)) and needs no consent record at
  // all — so there is NO consent wall, which is not a shortcut but the correct
  // reading: the ICO says consent is "unlikely to be the most appropriate
  // basis" for core-service processing and "in some circumstances it won't even
  // count as valid consent." A wall would produce INVALID consent AND the wrong
  // lawful basis simultaneously.
  //
  // What the contract basis DOES require is transparency (Arts. 13/14) at the
  // point of collection — which is why the notice mounts on SIGNUP and its
  // privacy link resolves PRE-LOGIN.
  //
  // Marketing is OFF by default (PECR requires opt-IN; the ICO has enforced on
  // pre-ticked boxes). The soft opt-in was considered and REJECTED. Under
  // Art. 7(1) consent must be DEMONSTRABLE — timestamped, per-user, with the
  // notice version — and we cannot demonstrate what we cannot store, so we send
  // NO marketing at all and the app says so. The record is session-scoped and
  // deliberately NOT disk-cached: a device-local consent record is not legal
  // evidence, it dies on cache-clear, and it is invisible to the support agent
  // who would have to prove it.
  //
  // TWO real mount sites — collection AND withdrawal — because Art. 7(3)
  // requires withdrawal to be as easy as giving. Group C needs one; the honesty
  // needs both.
  // MOUNT SITES: `marketing_consent_toggle.dart` (collection, mounted at signup)
  // AND `settings_screen.dart` (withdrawal).
  SeamEntry(
    gap: 74,
    feature: 'consent record',
    ledgerRef: 'row:34',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.rider,
        unavailableWidget: 'ConsentRecordUnavailable',
      ),
    ],
  ),

  // ══ DRIVER v3.0 — gap range #80–#99, SCOPE-TRACE rows 50+ ═══════════════
  //    APPEND-ONLY. Never interleave into a rider block; never renumber.

  // #84 OS location permission — SeamKind.device.
  //
  // NOT a backend hole: there is no endpoint to ask for. But the invariant is
  // identical. A driver whose OS location permission is denied sends NO
  // heartbeat, so the admin drops them from the dispatch pool after 5 minutes
  // — and today the app would happily show them a confident ONLINE state over
  // a driver nobody can reach. The device seam makes that a VISIBLE, REACHABLE
  // rung with a route to OS settings.
  //
  // `LocationUnavailableBanner` DOES NOT EXIST YET (there is no
  // `features/presence/` at all — `heartbeat()` has zero callers). **That RED
  // is the deliverable of Phase 0.** Phase 1 builds the presence riblet.
  SeamEntry(
    gap: 84,
    feature: 'location permission',
    ledgerRef: 'row:50',
    state: SeamState.SEAMED,
    kind: SeamKind.device,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.driver,
        unavailableWidget: 'LocationUnavailableBanner',
      ),
    ],
  ),

  // #85 ANDROID BACKGROUND LOCATION — SeamKind.device (v3.0 Phase 2).
  //
  // 🔴 THE SUBTLEST DEVICE LIE IN THE PRODUCT, AND THE MOST EXPENSIVE.
  //
  // #84 is the loud failure: no location at all, no ping, obviously broken.
  // THIS one is the quiet one, and it is worse, because everything LOOKS fine.
  //
  // Android 10 (API 29) split location into a two-stage grant. Stage one
  // ("While using the app") is what the system dialog offers, and it is what
  // most drivers will tap. Stage two ("Allow all the time",
  // ACCESS_BACKGROUND_LOCATION) is a SEPARATE request that cannot be bundled
  // with it — and on Android 11+ the OS will not even show a dialog for it: the
  // driver must be walked out to the Settings app.
  //
  // A driver with stage one only is a REAL, WORKING, DISPATCHABLE DRIVER. They
  // granted location. They tapped GO. The server has them in the pool. Offers
  // arrive. And the moment they lock their phone — which every driver does,
  // constantly, at every red light — Android stops delivering fixes, the
  // 20-second heartbeat starves, and the admin drops them from the pool five
  // minutes later. They sit in a layby watching a green ONLINE badge, earning
  // nothing, and blaming us.
  //
  // **A confident ONLINE badge over that driver is the same class of lie as a
  // fabricated payment card.** It tells them they are earning when they are not.
  //
  // NOT a backend hole — there is nothing to relay and no endpoint to ask for.
  // `POST /drivers/me/location` is BOUND and works; what is missing is the
  // DEVICE's consent to keep feeding it. Identical invariant, identical rung:
  // VISIBLE, REACHABLE, and it names the consequence in the driver's own terms
  // ("keep the app open"), never Android's ("permission not granted").
  //
  // It is a NOTICE, not an error. This driver can drive. They just cannot lock
  // their phone — and they have a right to know that before their shift, not
  // after it.
  SeamEntry(
    gap: 85,
    feature: 'background location',
    ledgerRef: 'row:51',
    state: SeamState.SEAMED,
    kind: SeamKind.device,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.driver,
        unavailableWidget: 'BackgroundLocationLimitedNotice',
      ),
    ],
  ),

  // #82 VEHICLE REGISTRATION / ASSIGNMENT FROM THE APP — SeamKind.view (Phase 3).
  //
  // 🔴 REGISTRATION3 IS A FORM THAT POSTS NOWHERE.
  //
  // The Figma's Registration3 collects the vehicle's registration plate, its
  // make and model, the insurance provider and the insurance expiry date.
  // **Nothing on the backend accepts a single one of them.** `Ride` carries a
  // `vehicle_id` the app never sets; vehicle assignment happens ADMIN-SIDE.
  // There is no `POST /drivers/me/vehicle`, and there is no endpoint that
  // would take these fields under any other name.
  //
  // MISSING_BE, not SEAMED, and the distinction matters: SEAMED means a
  // repository method exists and answers null. There is no method here and
  // there never was. A contributor who read SEAMED would go looking for one.
  //
  // A driver who fills that form, taps Continue and sees a green tick now
  // BELIEVES their vehicle is registered against their account. It is not.
  // They discover it when dispatch never matches them — or, far worse, when
  // somebody asks about insurance and the platform has no record they ever
  // told us. **A form that silently discards a driver's work while showing
  // them a success state is not a shortcut; it is a lie with a plausible UI.**
  //
  // So the wizard ships the STRUCTURE (the day the endpoint lands, the fields
  // drop straight in) and the RUNG (so the driver is told the truth today).
  // 13-03 mounts `VehicleRegistrationUnavailable` on the vehicle step and a
  // recording fake proves that step fires ZERO network calls.
  SeamEntry(
    gap: 82,
    feature: 'vehicle registration',
    ledgerRef: 'row:52',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.driver,
        unavailableWidget: 'VehicleRegistrationUnavailable',
      ),
    ],
  ),

  // #83 DOCUMENT VOCABULARY + THE `verification_status` ENUM — SeamKind.view.
  //
  // 🔴 THE BACKEND HAS PUBLISHED EXACTLY ONE STATUS WORD, AND THE FIGMA
  //    INVENTED A SECOND ONE THAT MEANS SOMETHING LEGAL.
  //
  // `DOCS/04` (L174) documents `pending_review` and says admin review moves a
  // document on from there — **without ever saying where to.** So the full
  // `verification_status` enum is UNPUBLISHED. We do not know the token for
  // approved, for rejected, for expired, or whether those are even the words.
  //
  // The Figma renders a green **"Valid"** badge. That string is not in the
  // backend's vocabulary at all. Rendering it over a `pending_review` DVLA
  // licence tells a driver **they may legally work** when we do not know that.
  // A driver who reads it and takes a fare is uninsured and unlicensed on our
  // word. It is the same species of defect as the fabricated accessibility
  // UUID this project has already paid for once — except it is about a
  // person's **right to work**, and it carries operator licensing exposure.
  //
  // The Figma is ALSO wrong about the types: it invents a `Medical
  // Certificate` (which would `400 VALIDATION_FAILED` — "invalid document
  // type") and OMITS three the backend requires (`mot_certificate`,
  // `v5c_logbook`, `caz_compliance_proof`). **D4: TRUTH WINS OVER FIGMA COPY.**
  //
  // So the app renders the server's own token, verbatim, and 13-01 mounts
  // `DocumentVocabularyUnavailable` under the list — permanently, not
  // conditionally, because the enum is not sometimes-unpublished. It says:
  // we will never tell you a document is valid unless the platform says so
  // in those words.
  SeamEntry(
    gap: 83,
    feature: 'document vocabulary',
    ledgerRef: 'row:53',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.driver,
        unavailableWidget: 'DocumentVocabularyUnavailable',
      ),
    ],
  ),

  // ══ DRIVER v3.0 PHASE 4 — TRIP SURFACE PARITY ═══════════════════════════
  //
  // 🔴 NOT ONE NEW NUMBER IS MINTED HERE. #86 STAYS FREE.
  //
  // Both entries below are for gaps this project has known about for months.
  // They had no `SeamEntry` because they lived only on a ledger BULLET — and a
  // rung that is not registered is not enforced, because every enforcement
  // group is a LOOP OVER THIS REGISTRY. An unregistered rung contributes zero
  // iterations: the checks do not fail, THEY DO NOT RUN.
  //
  // Minting #86 for "driver cancel" when #1 already IS driver cancel would give
  // one hole two rows, and group B would bind a seam to the wrong one — a
  // SILENT failure of the honesty instrument. One gap, one ledger row, N
  // disclosures.

  // #1 CANCELLATION REASONS — MISSING_BE. 🔴 AND IT BREAKS THE DRIVER TOO.
  //
  // `PATCH /rides/:id/cancel` requires a `reason_id` uuid that NO ENDPOINT
  // ANYWHERE LISTS. There is no `GET /cancellation-reasons`. So every cancel
  // 400s — and `actor_type: "driver"` hits the identical wall.
  //
  // This has been relayed for months AS A RIDER PROBLEM, and the backend team
  // has reasonably filed it as a rider cancel-flow nicety. It is not. With no
  // no-show mechanism (#44), a driver outside an empty house, with a rider who
  // is not coming, is TRAPPED IN A LIVE TRIP: they can sit there indefinitely,
  // or force-quit and leave the ride open server-side with themselves still
  // attached to it. It appears in NONE of the 45 Figma frames, and the design
  // actively asserts the opposite ("You cannot cancel a ride after accepting
  // it") while its own "You owe" sheet itemises a cancellation penalty.
  //
  // 🔴 WE DRAW NO CANCEL BUTTON. A button that 400s is worse than no button: it
  // teaches the driver the app is broken and leaves them exactly as trapped.
  // The rung says the true thing and routes to support
  // (`POST /me/support-tickets` — BOUND) — labelled honestly as a SUPPORT
  // TICKET, because that is what it is: it does not cancel the ride and it
  // moves no balance.
  //
  // MOUNT SITE: `stuck_exit_sheet.dart` constructs `CancelUnavailableState`.
  SeamEntry(
    gap: 1,
    feature: 'cancellation-reasons',
    ledgerRef: 'relayed-seamed',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.driver,
        unavailableWidget: 'CancelUnavailableState',
      ),
    ],
  ),

  // #44 WAITING POLICY / NO-SHOW — MISSING_BE.
  //
  // There is no free-wait window, no per-minute waiting rate, no charge
  // threshold, and no no-show mechanism. Nothing. The Figma's `(waiting time)`
  // frame shows a counter that plainly implies the driver is being PAID to sit
  // there.
  //
  // 🔴 SO THE CLOCK COUNTS **UP**, AND IT CARRIES NO MONEY. Elapsed time since
  // the local `arrive` stamp is honest and needs no backend at all. A countdown
  // toward "5:00 — wait charge starts" would be a FABRICATED PROMISE ABOUT A
  // SELF-EMPLOYED PERSON'S PAY. It would be believed, and it would be wrong,
  // and the driver would be short-paid and right to be angry. No countdown. No
  // accruing figure. Not greyed out, not "indicative", not a placeholder.
  //
  // MOUNT SITE: the arrived-at-pickup action zone constructs
  // `WaitingPolicyUnavailable`, which routes to the "I'm stuck" exit — because
  // a rung that names a hole and leaves the driver sitting in it is
  // half-honest, and this driver is LITERALLY sitting in it.
  // 🔴 LEDGER NOTE: #44 previously lived ONLY on the "Backend-without-frontend"
  // bullet ("waiting-charge countdown"), which group B's resolver cannot
  // address — it resolves `row:N` and `relayed-seamed`, and nothing else. So
  // this phase gives #44 a REAL ledger row (55) carrying both the `#44` token
  // and the `waiting-charge countdown` keyword. The gap is unchanged and
  // NOTHING is minted; it simply now sits somewhere the instrument can see it.
  SeamEntry(
    gap: 44,
    feature: 'waiting-charge countdown',
    ledgerRef: 'row:55',
    state: SeamState.MISSING_BE,
    kind: SeamKind.view,
    disclosures: [
      SeamDisclosure(
        app: SeamApp.driver,
        unavailableWidget: 'WaitingPolicyUnavailable',
      ),
    ],
  ),
];
