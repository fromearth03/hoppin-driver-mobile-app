import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/call/widgets/driver_call_unavailable_state.dart';
import 'package:hoppin_driver/features/dashboard/widgets/seam_unavailable_states.dart';
import 'package:hoppin_driver/features/documents/widgets/document_vocabulary_unavailable.dart';
import 'package:hoppin_driver/features/onboarding/widgets/vehicle_registration_unavailable.dart';
import 'package:hoppin_driver/features/presence/widgets/background_location_limited_notice.dart';
import 'package:hoppin_driver/features/presence/widgets/location_unavailable_banner.dart';
import 'package:hoppin_driver/features/trip/map/widgets/driver_map_unavailable.dart';
import 'package:hoppin_driver/features/trip/stuck/cancel_unavailable_state.dart';
import 'package:hoppin_driver/features/trip/widgets/waiting_policy_unavailable.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'support/source_scan.dart';

/// DS-04 group C (DRIVER half) — every driver seam's consumer renders a
/// DESIGNED unavailable-state, and that state is actually REACHABLE.
///
/// Group C is necessarily app-local: `apps/rider` cannot import `apps/driver`,
/// so one builder map can never cover both surfaces. [SeamApp] splits the
/// registry so each app asserts it covers EXACTLY its own seams — no gaps, no
/// orphans.
///
/// WHY THIS FILE EXISTS AT ALL (Wave 0, 2026-07-12): there was no driver-side
/// group C. `driver_repository`'s two capability seams — `todayStats()` (#7)
/// and `tripRiderContext()` (#6) — were shipping with no tag, no registry
/// entry, no ledger row and no designed rung, through three "green" phase
/// gates. The #7 hole was not cosmetic: the dashboard gated its online phase
/// on a telemetry emission that, on live, never came — so the GO button hung
/// as a disabled spinner while the driver was already in the dispatch pool,
/// unable to tell and unable to go back offline.
///
/// The reachability check below is the one that matters. Constructing a widget
/// in a bare harness proves it CAN render; it proves nothing about whether any
/// screen EVER MOUNTS IT. A widget that is declared but never constructed is
/// not a disclosure — it is dead code wearing a compliance badge.
void main() {
  // ProviderScope because some rungs are ConsumerWidgets — the #84 banner
  // reads the location seam for its "Open settings" exit. The rungs are still
  // pumped BARE (no app, no router, no repositories): a disclosure that needs
  // the whole app running to render is not a disclosure.
  Widget host(Widget child, {ThemeData? theme}) => ProviderScope(
        child: MaterialApp(
          theme: theme ?? HoppinTheme.driverDark(),
          home: Scaffold(
            body: Center(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      );

  /// 🔴 BOTH THEMES. A rung that throws (or renders invisible) in light mode is
  /// a rung nobody sees at 3pm — and the disclosure it carries is the only
  /// thing standing between a driver and a silent lie. The driver app defaults
  /// to dark, which is exactly why light mode is where a rung rots unnoticed.
  final themes = <String, ThemeData Function()>{
    'driverDark': HoppinTheme.driverDark,
    'driverLight': HoppinTheme.driverLight,
  };

  /// Bounded settle — never pumpAndSettle (project convention).
  Future<void> pumpBounded(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The designed fallback each DRIVER registry entry names.
  final builders = <String, Widget Function()>{
    // #7 driver day stats — no telemetry endpoint. The driver IS online and
    // IS taking rides; only the stats display is unavailable.
    'DriverStatsUnavailable': () => const DriverStatsUnavailable(),
    // #6 trip rider context — no rider-identity surface on the offer payload.
    'RiderContextUnavailable': () => const RiderContextUnavailable(),
    // #41 driverPosition + #17 rideGeo — BOTH null on every live request, so
    // the driver's nav canvas has no map, no route and no coordinates. This
    // used to render `SizedBox.shrink()`: a blank, on every live trip.
    'DriverMapUnavailable': () => const DriverMapUnavailable(),
    // #84 OS location permission (device seam). No fix → no heartbeat →
    // dispatch drops the driver in 5 minutes. The app must never show a
    // confident ONLINE state over a driver nobody can reach.
    'LocationUnavailableBanner': () => const LocationUnavailableBanner(),
    // #85 Android background location (device seam, Phase 2). The QUIET twin of
    // #84: this driver granted location, tapped GO, and IS dispatchable — and
    // their shift dies the instant they lock their phone, because Android 10+
    // makes "Allow all the time" a separate second-stage grant that most drivers
    // never see. A green ONLINE badge over them says they are earning when they
    // are about to stop. The rung names the consequence, not the Android fact.
    'BackgroundLocationLimitedNotice': () =>
        const BackgroundLocationLimitedNotice(),
    // #82 vehicle registration — Registration3 is a form that posts nowhere.
    // The backend accepts no plate, model, insurer or insurance expiry from
    // this app under any name; vehicle assignment is admin-side. The onboarding
    // wizard's vehicle step ships the STRUCTURE and mounts this rung
    // UNCONDITIONALLY, and fires zero network calls (13-03).
    'VehicleRegistrationUnavailable': () =>
        const VehicleRegistrationUnavailable(),
    // #83 document vocabulary — the backend documents only `pending_review`;
    // the full `verification_status` enum is UNPUBLISHED. The Documents surface
    // mounts this rung UNCONDITIONALLY beneath the eight rows, because a status
    // we cannot fully read is a status we must not fully assert (13-01).
    'DocumentVocabularyUnavailable': () =>
        const DocumentVocabularyUnavailable(),
    // ── v3.0 PHASE 4 (trip surface parity) — three EXISTING gaps that had
    //    never carried a DRIVER disclosure. No number is minted for any of them.

    // #45 masked voice call — the DRIVER's half of the rider's own gap. The
    // stake is higher on this side of the windscreen: with no masked bridge,
    // the only number a dial from the driver app could reach is the RIDER'S
    // PERSONAL MOBILE, which a private-hire driver must never hold. The surface
    // is built, reachable and inert; a recording gateway proves zero launches.
    'DriverCallUnavailableState': () => DriverCallUnavailableState(
          onOpenChat: () {},
        ),
    // #1 cancellation reasons — `PATCH /rides/:id/cancel` needs a `reason_id`
    // no endpoint lists, and `actor_type: "driver"` hits the identical wall. We
    // draw NO cancel button: one that 400s teaches the driver the app is broken
    // and leaves them exactly as trapped. The rung says so and routes to
    // support (BOUND), labelled honestly as a ticket — it cancels nothing.
    'CancelUnavailableState': () => const CancelUnavailableState(),
    // #44 waiting policy / no-show — no free-wait window, no per-minute rate,
    // no charge trigger, no no-show mechanism. The clock counts UP and carries
    // no money: a countdown toward a "wait charge" would be a fabricated
    // promise about a self-employed person's pay.
    'WaitingPolicyUnavailable': () => WaitingPolicyUnavailable(
          onOpenStuck: () {},
        ),
  };

  // v3.0 PHASE-0: a seam is one gap with N per-surface disclosures. This asks
  // "does the driver cover every disclosure it OWES?" — which now correctly
  // includes #41 and #17, the two seams the driver has been CONSUMING (and
  // rendering `SizedBox.shrink()` over) for three green phases while the RIDER
  // held the only disclosure.
  final driverOwed = seamDisclosuresFor(SeamApp.driver).toList();

  test('the driver app owes at least one disclosure (the split is wired)', () {
    expect(driverOwed, isNotEmpty,
        reason:
            'no driver disclosures — if the driver surface genuinely consumes '
            'no seams, delete this file; otherwise the registry split is wrong');
  });

  test('every DRIVER disclosure names a fallback widget with a builder', () {
    for (final owed in driverOwed) {
      expect(
        builders.containsKey(owed.disclosure.unavailableWidget),
        isTrue,
        reason:
            'seam #${owed.entry.gap} (${owed.entry.feature}) owes the driver a '
            'disclosure named "${owed.disclosure.unavailableWidget}" but group '
            'C has no builder for it — every SEAMED feature must ship a '
            'designed unavailable-state widget (the DS-04 DoD).',
      );
    }
  });

  test('group C has no builders for disclosures this app does not owe', () {
    final named =
        driverOwed.map((o) => o.disclosure.unavailableWidget).toSet();
    expect(
      builders.keys.toSet().difference(named),
      isEmpty,
      reason:
          'group C builds widgets that no DRIVER disclosure names — either the '
          'registry entry was removed (delete the builder) or the disclosure '
          'belongs to the rider surface (check its SeamDisclosure.app).',
    );
  });

  // THE REACHABILITY CHECK — the hole Wave 0 exists to close.
  test('every DRIVER disclosure widget is CONSTRUCTED in a real view', () {
    // 🔴 COMMENT-STRIPPED (15-00's source_scan). A doc comment NAMING a widget
    // is not a mount site. This sweep decides whether a rung is "reached", and
    // several of these rungs are explained at length in the prose above their
    // own mount sites — a raw read would let a paragraph about
    // `CancelUnavailableState` stand in for actually constructing it, which is
    // precisely the decorative-guard failure three lanes here have already paid
    // for.
    final sources = scanDartSources();

    expect(sources, isNotEmpty,
        reason:
            'the source sweep found NO dart files under lib/ — it would pass '
            'vacuously over an empty list, which looks exactly like a clean '
            'codebase. Fix the path before trusting a green.');

    final undeclared = <String>[];
    final orphans = <String>[];

    for (final name
        in driverOwed.map((o) => o.disclosure.unavailableWidget).toSet()) {
      final declaring = sources
          .where((s) => RegExp('class\\s+$name\\b').hasMatch(s.text))
          .toList();

      // COLLECT, do not abort. A bare `expect` inside the loop stops at the
      // first miss, and this instrument's whole job right now is to enumerate
      // the FULL red list in one run.
      if (declaring.isEmpty) {
        undeclared.add(name);
        continue;
      }
      final declPath = declaring.first.path;

      // Constructed directly, or presented via its `show<Name>` modal helper.
      final ctor = RegExp('(?<![\\w.])$name\\s*\\(');
      final showHelper = RegExp('(?<![\\w.])show$name\\s*\\(');
      final mounted = sources.any(
        (s) =>
            s.path != declPath &&
            (ctor.hasMatch(s.text) || showHelper.hasMatch(s.text)),
      );
      if (!mounted) orphans.add(name);
    }

    expect(
      undeclared,
      isEmpty,
      reason:
          'These disclosures are OWED by the driver surface and DECLARED '
          'NOWHERE in apps/driver/lib — the driver consumes the seam and shows '
          'the user nothing at all. Build each rung and mount it on its real '
          'null branch:\n  ${undeclared.join('\n  ')}',
    );

    expect(
      orphans,
      isEmpty,
      reason:
          'These designed unavailable-states are DECLARED BUT NEVER '
          'CONSTRUCTED by any view — the seam discloses nothing and the driver '
          'sees nothing, while the registry and the ledger both claim it '
          'degrades honestly. Mount each on its real null branch:\n'
          '  ${orphans.join('\n  ')}',
    );
  });

  for (final name
      in driverOwed.map((o) => o.disclosure.unavailableWidget).toSet()) {
    for (final theme in themes.entries) {
      testWidgets(
          '$name renders a designed non-blank unavailable-state '
          '(${theme.key})', (tester) async {
        final build = builders[name];
        expect(build, isNotNull, reason: 'no builder registered for "$name"');

        await tester.pumpWidget(host(build!(), theme: theme.value()));
        await pumpBounded(tester);

        final finder = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == name,
        );
        expect(finder, findsOneWidget,
            reason: '"$name" must render its designed surface in ${theme.key}');

        // Designed copy, not a blank pane.
        expect(find.byType(Text), findsWidgets,
            reason: '"$name" must render designed copy, not a blank box');

        // Real size — never a collapsed box (a "blank over null" in disguise).
        final size = tester.getSize(finder.first);
        expect(size.width, greaterThan(0),
            reason: '"$name" must not collapse to zero width in ${theme.key}');
        expect(size.height, greaterThan(0),
            reason: '"$name" must not collapse to zero height in ${theme.key}');
      });
    }
  }
}
