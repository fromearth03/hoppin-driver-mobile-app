import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_shared/hoppin_shared.dart';

/// DS-04 scope-trace enforcement (source + ledger halves).
///
/// This test is the machine-checkable acceptance instrument the milestone
/// depends on: it fails the build if a scope-locked feature is faked-as-live
/// rather than shaped as a disclosed seam that maps to the SCOPE-TRACE ledger.
///
///   GROUP A (source-shape): every REPOSITORY-kind seam's `SEAM(#n)` tag in
///     `rides_repository.dart` sits above a method with a nullable return AND
///     a `async => null` live body — the seam is SHAPED like a seam. VIEW-kind
///     seams (gated SDK gateways, geofence pre-flight, client eligibility,
///     deep-link landings) have no repository method, so group A skips them —
///     their ledger (B) + designed unavailable-state (C) checks still apply.
///   GROUP B (ledger cross-check, feature-matched): every `kSeamRegistry`
///     entry's `SEAM(#n)` references a ledger location that discloses THAT
///     feature — the gap token `#n` AND the feature keyword must BOTH appear on
///     the same referenced line. A wrong-row binding (e.g. driver-info → the
///     "Scheduled rides" row) therefore fails RED.
///
///   GROUP A0 (closed world): NO repository anywhere may contain an untagged
///     capability seam. Every `Future<T?> … async => null` method in EVERY
///     repository must carry a `SEAM(#n)` tag and a matching registry entry.
///     Without this the registry is OPEN-WORLD — a hole ships simply by never
///     being mentioned, which is exactly how `driver_repository`'s two seams
///     went undisclosed through three "green" phase gates.
///
///   GROUP B2 (consumption coverage — NEW, v3.0 Phase 0): if a repository
///     seam's method is CALLED anywhere in an app's `lib/`, that app MUST
///     appear in the seam's `disclosures`. **A surface that consumes a seam and
///     discloses nothing is the blank-canvas defect.** Group C could never see
///     this: it only asks "does each app cover the disclosures it CLAIMS?",
///     never "does it claim every disclosure it OWES?" — so the driver app
///     could consume #41 and #17 and disclose neither, for three green phases,
///     rendering `SizedBox.shrink()` over every live trip.
///
///   GAP-RANGE GUARD (NEW, v3.0 Phase 0): the rider (#70–#79) and driver
///     (#80–#99) milestones mint gap numbers in DISJOINT blocks. Two milestones
///     independently minting "the next number" collide, and a collision binds a
///     seam to the WRONG ledger row — a SILENT failure of the instrument.
///
/// HONEST LIMIT: groups A/A0/B2 are source-regex checks. They prove each seam
/// is shaped right, that none are hidden, and that no consumer is silent; they
/// do NOT prove a view renders the disclosure. That is group C's job (per app),
/// and — from v3.0 Phase 0 — group D's (the live-boot harness).
void main() {
  // Repo source (group A) and the ledger (group B), read via relative paths
  // from the package test dir. hoppin_shared/test/ → repo root is three levels
  // up; the ledger lives at repo-root .planning/.
  final ledger = File('../../.planning/SCOPE-TRACE.md').readAsStringSync();

  // EVERY repository file. Groups A0 and A both scan the whole directory —
  // scanning only `rides_repository.dart` is precisely how two driver seams
  // shipped undisclosed through three green phase gates.
  final repositoryFiles = Directory('lib/src/repositories')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final seamTagRe = RegExp(r'SEAM\(#(\d+)');

  group('DS-04 group A0 — closed world (no undisclosed seams anywhere)', () {
    // A capability seam is a nullable-returning method whose live body is
    // `async => null` — it answers "the backend cannot tell you" rather than
    // fabricating. Shape-match on the METHOD, so a hole cannot hide in a
    // repository group A does not scan.
    final seamShapeRe =
        RegExp(r'Future<[^>]+\?>\s+\w+\([^)]*\)\s*(async)?\s*=>\s*null;');

    test('every null-returning capability seam in EVERY repository is tagged',
        () {
      final undisclosed = <String>[];

      for (final file in repositoryFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!seamShapeRe.hasMatch(lines[i])) continue;

          // Walk BACK over the doc-comment block: a SEAM(#n) tag must be in it.
          var tagged = false;
          for (var j = i - 1; j >= 0; j--) {
            final line = lines[j].trimLeft();
            if (!line.startsWith('///')) break;
            if (line.contains('SEAM(#')) {
              tagged = true;
              break;
            }
          }

          if (!tagged) {
            final name = file.path.split(RegExp(r'[/\\]')).last;
            undisclosed.add('$name:${i + 1} → ${lines[i].trim()}');
          }
        }
      }

      expect(
        undisclosed,
        isEmpty,
        reason:
            'These are null-returning capability seams with NO SEAM(#n) tag — '
            'undisclosed backend holes. The registry is only a guarantee if it '
            'is CLOSED-WORLD: a seam that is never mentioned is a hole that '
            'ships silently. Tag each one and register it in kSeamRegistry '
            '(or bind it to a real endpoint):\n  ${undisclosed.join('\n  ')}',
      );
    });
  });

  group('DS-04 group A — seam source-shape', () {
    test('every SEAM(#n) tag annotates a nullable-return, null-body seam', () {
      final tagged = <int>[];

      // Scan EVERY repository — not just rides_repository.dart. Scanning one
      // file was how driver_repository's two seams shipped undisclosed, and it
      // would have left Phase 12's consent (#42) / deletion (#43) seams in
      // profile_repository.dart entirely unenforced.
      for (final file in repositoryFiles) {
        final lines = file.readAsLinesSync();
        final name = file.path.split(RegExp(r'[/\\]')).last;

        for (var i = 0; i < lines.length; i++) {
          final match = seamTagRe.firstMatch(lines[i]);
          if (match == null) continue;
          final gap = int.parse(match.group(1)!);
          tagged.add(gap);

          // The method sits on the first non-comment line after the tag block.
          var j = i + 1;
          while (j < lines.length && lines[j].trimLeft().startsWith('///')) {
            j++;
          }
          expect(j, lessThan(lines.length),
              reason: '$name: SEAM(#$gap) tag must annotate a method');
          final method = lines[j];

          expect(
            RegExp(r'Future<[^>]+\?>').hasMatch(method),
            isTrue,
            reason:
                '$name: SEAM(#$gap) — the annotated method must return a '
                'nullable Future (Future<...?>); the seam degrades to null. '
                'Line: $method',
          );
          expect(
            RegExp(r'async\s*=>\s*null;').hasMatch(method),
            isTrue,
            reason:
                '$name: SEAM(#$gap) — the live body must be `async => null`; a '
                'seam never fakes data on the live path. Line: $method',
          );
        }
      }

      // Every REPOSITORY-kind seam is tagged, and nothing extra is tagged.
      // VIEW-kind seams have no repository method — they are enforced by
      // groups B/C, not by a source tag here.
      final repoGaps = kSeamRegistry
          .where((e) => e.kind == SeamKind.repository)
          .map((e) => e.gap)
          .toList()
        ..sort();
      tagged.sort();
      expect(tagged, repoGaps,
          reason:
              'the SEAM(#n) tags across ALL repositories must match the '
              'REPOSITORY-kind kSeamRegistry entries exactly (one tag per '
              'repository seam, no orphans)');
    });

    test('the SEAM tag count equals the repository-kind registry length', () {
      final tagCount = repositoryFiles.fold<int>(
        0,
        (sum, f) => sum + seamTagRe.allMatches(f.readAsStringSync()).length,
      );
      final repoCount =
          kSeamRegistry.where((e) => e.kind == SeamKind.repository).length;
      expect(tagCount, repoCount,
          reason: 'one SEAM(#n) tag per repository-kind kSeamRegistry entry, '
              'counted across every repository file');
    });
  });

  group('DS-04 group B — ledger cross-check (feature-matched)', () {
    // Resolve a SeamEntry's ledgerRef to the single ledger line that must
    // disclose it.
    String ledgerLineFor(SeamEntry entry) {
      final lines = ledger.split('\n');
      if (entry.ledgerRef == 'relayed-seamed') {
        final line = lines.firstWhere(
          (l) => l.contains('**SEAMED (promote when endpoint ships):**'),
          orElse: () => '',
        );
        expect(line, isNotEmpty,
            reason:
                'ledgerRef "relayed-seamed" must resolve to the "Also relayed '
                'SEAMED" bullet in SCOPE-TRACE.md');
        return line;
      }
      final rowMatch = RegExp(r'^row:(\d+)$').firstMatch(entry.ledgerRef);
      expect(rowMatch, isNotNull,
          reason:
              'ledgerRef "${entry.ledgerRef}" must be "row:N" or '
              '"relayed-seamed"');
      final n = rowMatch!.group(1)!;
      final line = lines.firstWhere(
        (l) => RegExp('^\\|\\s*$n\\s*\\|').hasMatch(l),
        orElse: () => '',
      );
      expect(line, isNotEmpty,
          reason: 'ledgerRef "row:$n" must resolve to ledger row | $n | …');
      return line;
    }

    test('each seam\'s referenced ledger line carries its gap token AND feature',
        () {
      for (final entry in kSeamRegistry) {
        final line = ledgerLineFor(entry);

        // (i) the gap token #n is on THAT line.
        expect(
          line.contains('#${entry.gap}'),
          isTrue,
          reason:
              'SEAM(#${entry.gap}) → ${entry.ledgerRef}: the gap token '
              '"#${entry.gap}" is absent from the referenced ledger line — a '
              'wrong-row binding. Line: $line',
        );

        // (ii) the feature keyword is on that SAME line (case-insensitive).
        expect(
          line.toLowerCase().contains(entry.feature.toLowerCase()),
          isTrue,
          reason:
              'SEAM(#${entry.gap}) → ${entry.ledgerRef}: the feature keyword '
              '"${entry.feature}" is absent from the referenced ledger line — '
              'the tag discloses a DIFFERENT feature than the ledger row. This '
              'is the tightened cross-check: row number alone is not enough. '
              'Line: $line',
        );
      }
    });

    test('no seam binds to row 5 (Scheduled rides — an unrelated feature)', () {
      // Belt-and-braces against the regression this fix corrected: row 5 is
      // "Scheduled rides"; no capability seam here discloses that feature.
      for (final entry in kSeamRegistry) {
        expect(entry.ledgerRef, isNot('row:5'),
            reason:
                'SEAM(#${entry.gap}) must not bind to row 5 (Scheduled rides)');
      }
    });
  });

  // ══ GROUP B2 — CONSUMPTION COVERAGE ════════════════════════════════════
  //
  // If an app's `lib/` CALLS a repository seam's method, that app OWES a
  // disclosure. Full stop.
  //
  // This is the check that would have caught the driver's blank map three
  // phases ago. Group C can only ask "does each app cover the disclosures it
  // CLAIMS?" — it is structurally blind to a disclosure the registry never
  // claimed in the first place. So `apps/driver` called `driverPosition()` and
  // `rideGeo()`, both answered null on every live trip, the map collapsed to
  // `SizedBox.shrink()`, and every gate stayed green: the seam WAS disclosed —
  // by the RIDER — and nothing anywhere asked whether the driver, who also
  // consumed it, disclosed anything at all.
  //
  // One gap. One ledger row. N disclosures — one per consuming surface.
  group('DS-04 group B2 — consumption coverage (a consumer owes a rung)', () {
    /// gap → the repository method name its SEAM(#n) tag annotates.
    /// Derived from SOURCE, not from a hand-maintained table: a table would
    /// drift, and a drifted enforcement instrument is worse than none.
    final seamMethods = <int, String>{};
    final methodDeclRe = RegExp(r'Future<[^>]+\?>\s+(\w+)\s*\(');

    for (final file in repositoryFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final tag = seamTagRe.firstMatch(lines[i]);
        if (tag == null) continue;
        var j = i + 1;
        while (j < lines.length && lines[j].trimLeft().startsWith('///')) {
          j++;
        }
        if (j >= lines.length) continue;
        final decl = methodDeclRe.firstMatch(lines[j]);
        if (decl != null) {
          seamMethods[int.parse(tag.group(1)!)] = decl.group(1)!;
        }
      }
    }

    /// Every `.dart` source under an app's `lib/`, as (path, text).
    List<({String path, String text})> appSources(String app) {
      final dir = Directory('../../apps/$app/lib');
      if (!dir.existsSync()) return const [];
      return dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => (path: f.path, text: f.readAsStringSync()))
          .toList();
    }

    final surfaces = <SeamApp, List<({String path, String text})>>{
      SeamApp.rider: appSources('rider'),
      SeamApp.driver: appSources('driver'),
    };

    test('both app surfaces are readable from hoppin_shared/test', () {
      // If this fails the whole group is silently vacuous — a green B2 over an
      // empty file list proves nothing at all. Fail loudly instead.
      for (final entry in surfaces.entries) {
        expect(entry.value, isNotEmpty,
            reason:
                'no Dart sources found under apps/${entry.key.name}/lib — B2 '
                'cannot see the surface it is supposed to check, so it would '
                'pass vacuously. Fix the relative path before trusting a green.');
      }
    });

    test('every app that CALLS a repository seam declares a disclosure for it',
        () {
      final violations = <String>[];

      for (final entry in kSeamRegistry) {
        if (entry.kind != SeamKind.repository) continue;
        final method = seamMethods[entry.gap];
        if (method == null) continue; // group A already fails this case

        // A call site: `.method(` — the leading dot is what distinguishes a
        // CALL from the declaration itself (which we never scan; the repos live
        // in packages/, not apps/).
        final callRe = RegExp('\\.$method\\s*\\(');

        for (final app in SeamApp.values) {
          final callers = surfaces[app]!
              .where((s) => callRe.hasMatch(s.text))
              .map((s) => s.path)
              .toList();
          if (callers.isEmpty) continue;

          final discloses = entry.disclosureFor(app) != null;
          if (!discloses) {
            violations.add(
              'SEAM(#${entry.gap}) "${entry.feature}" — $method() is CALLED in '
              'apps/${app.name}/lib but ${app.name} declares NO disclosure:\n'
              '      ${callers.join('\n      ')}',
            );
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'CONSUMPTION COVERAGE FAILURE. These surfaces consume a capability '
            'seam and disclose NOTHING when it answers null — the blank-canvas '
            'defect. A gap is ONE fact; its disclosure is PER-SURFACE, and each '
            'surface owes its own honest state in its own voice. Add a '
            'SeamDisclosure for the consuming app (and build the rung — group C '
            'will then demand it be constructed in a real view):\n\n  '
            '${violations.join('\n\n  ')}',
      );
    });

    test('no seam declares a disclosure for an app that never consumes it', () {
      // The inverse. A disclosure for a surface that does not call the seam is
      // a compliance badge over nothing: it inflates the coverage number and it
      // forces group C to keep a widget alive that no null branch can reach.
      final orphans = <String>[];

      for (final entry in kSeamRegistry) {
        if (entry.kind != SeamKind.repository) continue;
        final method = seamMethods[entry.gap];
        if (method == null) continue;
        final callRe = RegExp('\\.$method\\s*\\(');

        for (final d in entry.disclosures) {
          final consumes = surfaces[d.app]!.any((s) => callRe.hasMatch(s.text));
          if (!consumes) {
            orphans.add(
              'SEAM(#${entry.gap}) "${entry.feature}" declares a '
              '${d.app.name} disclosure ("${d.unavailableWidget}") but '
              'apps/${d.app.name}/lib never calls $method()',
            );
          }
        }
      }

      expect(orphans, isEmpty,
          reason:
              'These disclosures answer a seam the surface does not consume:\n'
              '  ${orphans.join('\n  ')}');
    });
  });

  // ══ GAP-RANGE GUARD — parallel-milestone allocator safety ═══════════════
  //
  // Rider v2.0 mints #70–#79. Driver v3.0 mints #80–#99. Two milestones
  // independently taking "the next free number" WILL collide, and a collision
  // does not fail loudly — it binds a seam to the WRONG ledger row and the
  // instrument goes on reporting green while disclosing a different feature
  // than it claims to. A convention nobody can violate accidentally beats a
  // convention in a doc.
  group('gap-number allocator — milestone ranges stay disjoint', () {
    test('every newly-minted gap sits in its milestone block', () {
      // Anything <= 69 predates the split and is unconstrained.
      final minted = kSeamRegistry.where((e) => e.gap >= kGapRangeFloor);

      for (final entry in minted) {
        final inRider =
            entry.gap >= kRiderGapRange.min && entry.gap <= kRiderGapRange.max;
        final inDriver = entry.gap >= kDriverGapRange.min &&
            entry.gap <= kDriverGapRange.max;

        expect(inRider || inDriver, isTrue,
            reason:
                'gap #${entry.gap} ("${entry.feature}") is outside BOTH '
                'milestone blocks (rider ${kRiderGapRange.min}-'
                '${kRiderGapRange.max}, driver ${kDriverGapRange.min}-'
                '${kDriverGapRange.max}). Mint from your own range.');

        // A driver-only seam must not be minted from the rider's block, and
        // vice versa — that is the collision this guard exists to prevent.
        final onlyDriver = entry.apps.length == 1 &&
            entry.apps.contains(SeamApp.driver);
        final onlyRider =
            entry.apps.length == 1 && entry.apps.contains(SeamApp.rider);

        if (onlyDriver) {
          expect(inDriver, isTrue,
              reason:
                  'gap #${entry.gap} ("${entry.feature}") is a DRIVER-only seam '
                  'minted from the rider block (#${kRiderGapRange.min}-'
                  '#${kRiderGapRange.max}). Driver v3.0 mints '
                  '#${kDriverGapRange.min}-#${kDriverGapRange.max}.');
        }
        if (onlyRider) {
          expect(inRider, isTrue,
              reason:
                  'gap #${entry.gap} ("${entry.feature}") is a RIDER-only seam '
                  'minted from the driver block (#${kDriverGapRange.min}-'
                  '#${kDriverGapRange.max}). Rider v2.0 mints '
                  '#${kRiderGapRange.min}-#${kRiderGapRange.max}.');
        }
      }
    });

    test('no gap number is minted twice', () {
      final seen = <int>{};
      final dupes = <int>[];
      for (final entry in kSeamRegistry) {
        if (!seen.add(entry.gap)) dupes.add(entry.gap);
      }
      expect(dupes, isEmpty,
          reason:
              'duplicate gap numbers in kSeamRegistry: $dupes. One gap is ONE '
              'entry with N disclosures — never two entries. A duplicate breaks '
              "group A's tag-count assertion and binds two seams to one row.");
    });
  });

  // ══ SEAM-AS-GATE LINT — the standing rule, made machine-checkable ═══════
  //
  // > A capability seam may only feed DECORATION — never presence, never
  // > navigation, never lifecycle.
  //
  // All four known driver live-bugs are violations of that one rule. `#7`
  // (`todayStats()` → null on live, always) is the sole source of
  // `payoutPence` AND `activeRideId`, so a completed trip strands the driver on
  // a dead card and a mid-trip refresh loses the trip entirely. The seam was
  // "disclosed" — and it was still load-bearing for navigation.
  //
  // A grep cannot prove the general case. What it CAN do is fail the specific,
  // named, load-bearing couplings we have found, so that a fix cannot silently
  // regress and a new one cannot be added by copy-paste.
  group('seam-as-gate lint — a seam may feed only DECORATION', () {
    List<({String path, String text})> driverSources() {
      final dir = Directory('../../apps/driver/lib');
      if (!dir.existsSync()) return const [];
      return dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => (path: f.path, text: f.readAsStringSync()))
          .toList();
    }

    test('navigation state (activeRideId) is not sourced from a seam payload',
        () {
      // KNOWN RED (v3.0 Phase 0). `dashboard_interactor.dart` assigns
      // activeRideId inside _onStats(DriverDayStats) — the #7 seam handler,
      // which NEVER fires on live. dashboard_router.dart then gates the
      // trip-resume redirect on it, so a driver who refreshes mid-trip is
      // dumped on the dashboard with no way back into the running trip.
      //
      // Phase 1 (W0-11) sources activeRideId from a BOUND `GET /rides` read.
      final offenders = <String>[];
      for (final s in driverSources()) {
        final lines = s.text.split('\n');
        var inStatsHandler = false;
        var braceDepth = 0;
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (RegExp(r'void\s+_onStats\s*\(').hasMatch(line)) {
            inStatsHandler = true;
            braceDepth = 0;
          }
          if (!inStatsHandler) continue;
          braceDepth += '{'.allMatches(line).length;
          braceDepth -= '}'.allMatches(line).length;
          if (RegExp(r'activeRideId\s*:').hasMatch(line)) {
            offenders.add('${s.path}:${i + 1} → ${line.trim()}');
          }
          if (braceDepth <= 0 && line.contains('}')) inStatsHandler = false;
        }
      }
      expect(offenders, isEmpty,
          reason:
              'NAVIGATION STATE IS GATED ON A CAPABILITY SEAM. `activeRideId` '
              'drives the mid-trip resume redirect, and it is being written '
              'from the #7 (`todayStats`) seam handler — which returns null on '
              'every live request. A driver who refreshes mid-trip loses the '
              'trip. Source it from a BOUND read:\n  ${offenders.join('\n  ')}');
    });

    test('a seam-fed figure does not gate a lifecycle transition', () {
      // KNOWN RED (v3.0 Phase 0). `trip_runner_router.dart` gates the
      // earned-moment attach — the driver's ONLY exit from the completed trip —
      // on `payoutPence != null`, and payoutPence is written only inside
      // _onStats (the #7 seam). On live the sheet never attaches and the runner
      // never leaves the completed card. A MONEY FIGURE IS DECORATION. It must
      // never decide whether the driver can leave the screen.
      final offenders = <String>[];
      for (final s in driverSources()) {
        if (!s.path.contains('router')) continue;
        final lines = s.text.split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (RegExp(r'payoutPence\s*!=\s*null').hasMatch(lines[i])) {
            offenders.add('${s.path}:${i + 1} → ${lines[i].trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason:
              'A LIFECYCLE TRANSITION IS GATED ON A SEAM-FED FIGURE. '
              '`payoutPence` comes from the #7 seam (null on every live '
              'request) and it decides whether the driver can EXIT a completed '
              'trip. The trip must complete with or without a figure — the '
              'figure is decoration:\n  ${offenders.join('\n  ')}');
    });
  });

  // ══ DRIVER v3.0 PHASE 3 — THE FRONT-DOOR SEAMS (#82, #83) ═══════════════
  //
  // Two facts the driver's front door depends on, and neither exists:
  //
  //   #82 — Registration3 collects a registration plate, a make/model, an
  //         insurer and an insurance expiry date. NOTHING on the backend
  //         accepts a single one of them. `Ride` carries a `vehicle_id` the
  //         app never sets; vehicle assignment is admin-side. A form that
  //         silently discards a driver's work while showing them a success
  //         state is not a shortcut — it is a lie with a plausible UI.
  //
  //   #83 — `DOCS/04` publishes exactly ONE `verification_status` value
  //         (`pending_review`) and says admin review moves a document on from
  //         there, without saying WHERE TO. The Figma renders a green "Valid"
  //         badge over that. Telling a driver their DVLA licence is Valid when
  //         we do not know it is tells them THEY MAY LEGALLY WORK. That is a
  //         lie about a person's right to work, with operator-licensing
  //         exposure behind it.
  //
  // These are MISSING_BE, not SEAMED. SEAMED means a repository method exists
  // and answers null. There is no method here and there never was — a
  // contributor who read SEAMED would go looking for one and never find it.
  group('driver v3.0 Phase 3 — the front-door seams', () {
    SeamEntry entryFor(int gap) =>
        kSeamRegistry.singleWhere((e) => e.gap == gap);

    /// The relay, read the same way group B reads the ledger — relative from
    /// the package test dir, three levels up to the repo root.
    final relay = File('../../DOCS/06-backend-gaps-relay.md').readAsStringSync();

    test('TEST 1 — #82 (vehicle registration) is registered, MISSING_BE, view',
        () {
      final e = entryFor(82);
      expect(e.state, SeamState.MISSING_BE,
          reason:
              '#82 is MISSING_BE, not SEAMED. SEAMED means a repository method '
              'exists and answers null. NOTHING on the backend accepts a '
              'registration plate under any name, and there is no repository '
              'method to find — calling it SEAMED would send a contributor '
              'looking for a seam that does not exist.');
      expect(e.kind, SeamKind.view,
          reason: '#82 has no repository method — group A must skip it');
    });

    test('TEST 2 — #82 discloses on the DRIVER surface only', () {
      final e = entryFor(82);
      expect(e.disclosures.length, 1,
          reason:
              'the rider never sees the vehicle wizard and must not declare a '
              'disclosure for it — a disclosure for a surface that never '
              'consumes the seam is a compliance badge over nothing');
      expect(e.disclosures.single.app, SeamApp.driver);
      expect(e.disclosures.single.unavailableWidget,
          'VehicleRegistrationUnavailable',
          reason:
              'the widget name is FIXED by plan 13-00; 13-03 mounts exactly '
              'this class on the vehicle step. A one-character disagreement '
              'fails group C.');
    });

    test('TEST 3 — #83 (document vocabulary) is registered, MISSING_BE, view, '
        'driver-disclosed', () {
      final e = entryFor(83);
      expect(e.state, SeamState.MISSING_BE);
      expect(e.kind, SeamKind.view);
      expect(e.disclosures.length, 1);
      expect(e.disclosures.single.app, SeamApp.driver);
      expect(
          e.disclosures.single.unavailableWidget, 'DocumentVocabularyUnavailable',
          reason:
              'the widget name is FIXED by plan 13-00; 13-01 mounts exactly '
              'this class under the documents list');
    });

    test('TEST 4 — the ledger rows 52 and 53 resolve and carry gap + feature',
        () {
      final lines = ledger.split('\n');

      for (final gap in [82, 83]) {
        final e = entryFor(gap);
        final rowMatch = RegExp(r'^row:(\d+)$').firstMatch(e.ledgerRef);
        expect(rowMatch, isNotNull,
            reason: '#$gap ledgerRef must be "row:N"; got "${e.ledgerRef}"');
        final n = rowMatch!.group(1)!;

        final line = lines.firstWhere(
          (l) => RegExp('^\\|\\s*$n\\s*\\|').hasMatch(l),
          orElse: () => '',
        );
        expect(line, isNotEmpty,
            reason:
                '#$gap → ledger row $n does not exist in SCOPE-TRACE.md. A '
                'registry entry pointing at a row nobody wrote is a compliance '
                'badge worn by nothing.');
        expect(line.contains('#$gap'), isTrue,
            reason: 'ledger row $n must carry the gap token "#$gap". Line: $line');
        expect(line.toLowerCase().contains(e.feature.toLowerCase()), isTrue,
            reason:
                'ledger row $n must carry the feature word "${e.feature}" — '
                'row number alone is not enough; a wrong-row binding discloses '
                'a DIFFERENT feature than it claims to. Line: $line');
      }
    });

    test('TEST 5 — APPEND-ONLY, PROVEN: the driver block tail is [84, 85, 82, 83]',
        () {
      // 🔴 A NUMERICALLY SORTED [82, 83, 84, 85] FAILS THIS TEST ON PURPOSE.
      //
      // The rider milestone appends to this SAME list in a parallel lane. Two
      // tail-appends merge cleanly; an INTERLEAVE does not — it rewrites lines
      // both branches touched, and the conflict resolution is done by hand,
      // under time pressure, on a list where a single misplaced entry silently
      // re-points a `ledgerRef` at the wrong feature and the suite STAYS GREEN
      // (group B still finds a row; it is just the wrong one).
      //
      // So the ordering is not cosmetic and it is not taste. It is the
      // structural property that makes a renumbering accident impossible.
      final driverGaps = kSeamRegistry
          .where((e) => e.gap >= kDriverGapRange.min &&
              e.gap <= kDriverGapRange.max)
          .map((e) => e.gap)
          .toList();

      expect(driverGaps.length, greaterThanOrEqualTo(4),
          reason: 'expected at least the four driver v3.0 gaps 84/85/82/83');
      expect(driverGaps.sublist(driverGaps.length - 4), [84, 85, 82, 83],
          reason:
              'THE DRIVER BLOCK IS APPEND-ONLY. #82 and #83 must be the LAST '
              'two entries in kSeamRegistry, appended after #85 — never sorted '
              'into numeric order. Two tail-appends from two parallel '
              'milestones merge cleanly; an interleave does not, and a '
              'hand-resolved conflict in this list re-points a ledgerRef at '
              'the wrong feature while the suite stays green.');
    });

    test('TEST 6 — #82 and #83 are in the driver block and minted exactly once',
        () {
      for (final gap in [82, 83]) {
        expect(gap, greaterThanOrEqualTo(kDriverGapRange.min));
        expect(gap, lessThanOrEqualTo(kDriverGapRange.max));

        final count = kSeamRegistry.where((e) => e.gap == gap).length;
        expect(count, 1,
            reason:
                '#$gap must be minted EXACTLY once. Zero = the seam does not '
                'exist. Two = a copy-paste, and two entries bound to one '
                'ledger row is a silent Group-B failure.');
      }
    });

    test('TEST 7 — the relay carries #82, #83, #29 and #49 — and #49 is BLOCKING',
        () {
      for (final token in ['#82', '#83', '#29', '#49']) {
        expect(relay.contains(token), isTrue,
            reason:
                'DOCS/06-backend-gaps-relay.md must name $token. A seam minted '
                'and never relayed is a gap the backend team has never been '
                'told about.');
      }

      // 🔴 NOT A DOCUMENTATION-VANITY ASSERTION.
      //
      // #49 means the invite email a real driver receives lands on a URL with
      // NO PAGE BEHIND IT. A genuinely provisioned driver cannot set a
      // password, cannot sign in, and therefore CANNOT REACH A SINGLE SCREEN
      // this entire phase builds. A relay that files that next to
      // "nice-to-have: a profile endpoint" is a relay the backend team will
      // correctly deprioritise. The word must be in the text.
      //
      // Scan EVERY #49 mention, not just the last: which mention happens to be
      // last is an accident of append order, and pinning the assertion to it
      // would go red the day someone appends an unrelated #49 cross-reference
      // — a false alarm that trains people to weaken the test. The invariant is
      // "SOME #49 mention states the block", and that is what is asserted.
      final windows = RegExp('#49').allMatches(relay).map((m) => relay
          .substring(m.start, (m.start + 600).clamp(0, relay.length))
          .toLowerCase());
      expect(windows.any((w) => w.contains('block')), isTrue,
          reason:
              'The #49 relay must say, in plain English, that it BLOCKS the '
              'driver front door. It is not a deep-link nicety — it is the '
              'only way in. Everything Phase 13 builds is correct and '
              'unreachable until the Supabase invite redirect target is '
              'configured.');
    });
  });
}
