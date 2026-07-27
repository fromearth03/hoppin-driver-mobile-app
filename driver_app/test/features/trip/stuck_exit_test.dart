import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoppin_driver/features/motion/motion_builder.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/features/trip/map/map_interactor.dart';
import 'package:hoppin_driver/features/trip/map/map_state.dart';
import 'package:hoppin_driver/features/trip/stuck/cancel_unavailable_state.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_interactor.dart';
import 'package:hoppin_driver/features/trip/trip_runner_state.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '../../support/source_scan.dart';

/// 🔴 THE TRAPPED-DRIVER EXIT — THE MOST SERIOUS THING IN THE PHASE.
///
/// `PATCH /rides/:id/cancel` requires a `reason_id` uuid that NO endpoint
/// anywhere lists (#1) — so EVERY cancel 400s, `actor_type: "driver"` included.
/// There is no no-show mechanism (#44). So a driver outside a no-show pickup is
/// TRAPPED in a live trip: they can sit there indefinitely, or force-quit and
/// leave the ride open server-side with themselves still attached.
///
/// So: ship a reachable "I'm stuck" exit that routes to support (BOUND),
/// disclose that a real cancel is not yet possible, and NEVER draw a button
/// that would 400. A cancel button that fails is worse than no button.
void main() {
  const rideId = 'ride-1';

  /// Bounded pumps only — NEVER `pumpAndSettle` (live polling providers).
  Future<void> bounded(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Boots the REAL trip runner over live-shaped repos at [phase]. The rider
  /// seam answers null (exactly as live); the support + rides repos record.
  Future<_Recording> pumpRealRunner(
    WidgetTester tester,
    TripPhase phase, {
    _RecordingSupport? support,
    _RecordingRides? rides,
  }) async {
    final rec = _Recording(
      support: support ?? _RecordingSupport(),
      rides: rides ?? _RecordingRides(),
    );
    // A real GoRouter so `context.push('/trip/:id/chat|call')` RESOLVES rather
    // than throwing on a routerless MaterialApp. 15-01/15-02 own the real chat
    // and call screens; here they are throwaway placeholders so the comms taps
    // land somewhere — this test asserts about the STUCK sheet, not those
    // screens.
    final router = GoRouter(
      initialLocation: '/trip/$rideId',
      routes: [
        GoRoute(
          path: '/trip/:id',
          builder: (_, state) =>
              TripRunnerRiblet(rideId: state.pathParameters['id']!),
          routes: [
            GoRoute(path: 'chat', builder: (_, _) => const _StubDest('chat')),
            GoRoute(path: 'call', builder: (_, _) => const _StubDest('call')),
          ],
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        // A stub runner pinned to the phase under test — the real card, its
        // real action zone, its real comms row and stuck control render over
        // it; only the lifecycle intents are inert.
        tripRunnerInteractorProvider
            .overrideWith2((id) => _PhaseRunner(phase)),
        tripMapInteractorProvider.overrideWith2((id) => _StubMap()),
        supportRepositoryProvider.overrideWithValue(rec.support),
        ridesRepositoryProvider.overrideWithValue(rec.rides),
      ],
      child: MaterialApp.router(
        theme: HoppinTheme.driverDark(),
        routerConfig: router,
      ),
    ));
    await bounded(tester);
    return rec;
  }

  // ── S1 — EVERY TRIP PHASE HAS A FORWARD EXIT ────────────────────────────
  group('🔴 S1 — every phase has a reachable forward exit', () {
    for (final phase in TripPhase.values) {
      testWidgets('$phase offers a way that is not "sit here forever"',
          (tester) async {
        await pumpRealRunner(tester, phase);

        // The phase's own advance…
        final advance = switch (phase) {
          TripPhase.headingToPickup =>
            find.widgetWithText(HopButton, 'Arrived'),
          TripPhase.arrivedAtPickup ||
          TripPhase.inTrip =>
            find.byType(SlideToConfirm),
          TripPhase.completed => find.widgetWithText(HopButton, 'Done'),
        };

        // …OR the stuck exit. Either one being present satisfies the invariant.
        final stuck = find.widgetWithText(HopButton, "I'm stuck");

        final hasAdvance = tester.any(advance);
        final hasStuck = tester.any(stuck);
        expect(
          hasAdvance || hasStuck,
          isTrue,
          reason: '🔴 $phase has NO forward exit. A driver in a parked car '
              'with a live job and no options is exactly what this plan '
              'exists to prevent (Group-D invariant, per phase).',
        );
      });
    }
  });

  // ── S2 — the stuck exit is reachable from a no-show, in ≤2 taps ─────────
  testWidgets('S2 — stuck exit opens in ≤2 taps at arrivedAtPickup',
      (tester) async {
    await pumpRealRunner(tester, TripPhase.arrivedAtPickup);

    final stuck = find.widgetWithText(HopButton, "I'm stuck");
    expect(stuck, findsOneWidget, reason: 'no "I\'m stuck" control at a no-show');

    // Tap 1: open the sheet.
    await tester.tap(stuck);
    await bounded(tester);

    expect(
      find.byType(CancelUnavailableState),
      findsOneWidget,
      reason: 'the sheet must render the #1 rung — a real cancel is impossible '
          'and it must be said out loud.',
    );
  });

  // ── S3 — NO CANCEL BUTTON THAT WOULD 400 ────────────────────────────────
  group('🔴 S3 — no cancel that would 400 (#1)', () {
    test('source: zero .cancel( calls and zero cancel-shaped labels under '
        'features/trip (comment-stripped)', () {
      final sources = scanDartSources()
          .where((s) => s.path.contains('/features/trip/'))
          .toList();
      expect(sources, isNotEmpty, reason: 'the sweep must sweep something');

      final offenders = <String>[];
      // A REPOSITORY cancel — the thing that 400s (#1). `RidesRepository.cancel`
      // takes reasonId / canceledByUserId / actorType, so a cancel call site is
      // unmistakable by those names, or by `.cancel(rideId:`. A bare `.cancel()`
      // is NOT flagged — `Timer.cancel()` and `StreamSubscription.cancel()` are
      // legitimate and unrelated (the map poll, the waiting-clock tick).
      final repoCancel = RegExp(
        r'\.cancel\s*\(\s*(rideId|reasonId|canceledByUserId|actorType)\b',
      );
      // A rendered CONTROL whose LABEL offers a cancel/no-show — never drawn,
      // because it would 400. Prose that merely explains the ban is fine; a
      // `label:`/`'…'` that a driver taps is not.
      final cancelLabel = RegExp(
        r"""(label\s*:\s*|widgetWithText\([^,]+,\s*)['"][^'"]*"""
        r"""(Cancel ride|Cancel trip|No.?show)""",
        caseSensitive: false,
      );
      for (final source in sources) {
        for (var i = 0; i < source.lines.length; i++) {
          final line = source.lines[i];
          if (repoCancel.hasMatch(line) || cancelLabel.hasMatch(line)) {
            offenders.add('${source.path}:${i + 1}  ${line.trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: '🔴 a repository cancel call or a cancel-shaped control is on '
            'the trip surface. Every cancel 400s (#1); a button that fails is '
            'worse than no button:\n${offenders.join('\n')}',
      );
    });

    testWidgets('runtime: driving EVERY control on the stuck sheet calls '
        'cancel() ZERO times', (tester) async {
      final rides = _RecordingRides();
      await pumpRealRunner(tester, TripPhase.arrivedAtPickup, rides: rides);

      Future<void> openSheet() async {
        if (tester.any(find.byType(CancelUnavailableState))) return;
        // Chat/Call navigate to a stub route; go back to the runner first.
        while (tester.any(find.text('stub-chat')) ||
            tester.any(find.text('stub-call'))) {
          final router = GoRouter.maybeOf(
            tester.element(find.byType(Scaffold).first),
          );
          router?.go('/trip/$rideId');
          await bounded(tester);
        }
        await tester.tap(find.widgetWithText(HopButton, "I'm stuck"));
        await bounded(tester);
      }

      await openSheet();
      // Snapshot how many controls the sheet has, then tap EACH from a freshly
      // re-opened sheet. 🔴 This is what stops a navigating control (Chat/Call
      // pops the sheet) from SHIELDING a cancel button placed after it — every
      // index gets its own clean, fully-populated sheet.
      final controlCount = tester.widgetList(find.byType(HopButton)).length +
          tester.widgetList(find.byType(TextButton)).length +
          tester.widgetList(find.byType(InkWell)).length;

      for (var i = 0; i < controlCount; i++) {
        await openSheet();
        final all = <Finder>[
          ...List.generate(
              tester.widgetList(find.byType(HopButton)).length,
              (j) => find.byType(HopButton).at(j)),
          ...List.generate(
              tester.widgetList(find.byType(TextButton)).length,
              (j) => find.byType(TextButton).at(j)),
          ...List.generate(
              tester.widgetList(find.byType(InkWell)).length,
              (j) => find.byType(InkWell).at(j)),
        ];
        if (i >= all.length) continue;
        final target = all[i];
        if (!tester.any(target)) continue;
        try {
          await tester.tap(target, warnIfMissed: false);
        } catch (_) {
          continue;
        }
        await bounded(tester);
      }

      expect(
        rides.cancelCalls,
        0,
        reason: '🔴 cancel() was reached — through a helper, or a control. The '
            'recording repo cannot be dodged: every cancel 400s (#1).',
      );
    });
  });

  // ── S4 — the exit files a support ticket AND SAYS SO ────────────────────
  testWidgets('S4 — Contact support files a ticket carrying the ride id, and '
      'the copy never claims a cancellation', (tester) async {
    final support = _RecordingSupport();
    await pumpRealRunner(tester, TripPhase.arrivedAtPickup, support: support);

    await tester.tap(find.widgetWithText(HopButton, "I'm stuck"));
    await bounded(tester);

    await tester.tap(find.widgetWithText(HopButton, 'Contact support'));
    await bounded(tester);

    expect(support.createCalls, 1, reason: 'the support ticket was not filed');
    expect(
      support.lastSubject?.contains(rideId) == true ||
          support.lastBody?.contains(rideId) == true,
      isTrue,
      reason: 'the ticket must carry the ride id so support can find the trip',
    );

    // The sheet's copy must contain "support" and must NOT claim the trip will
    // be cancelled, the driver paid, or a penalty waived.
    final allText = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ')
        .toLowerCase();
    expect(allText.contains('support'), isTrue,
        reason: 'the exit routes to SUPPORT — it must say so');
    for (final lie in ['cancelled the ride', 'you will be paid', 'penalty waived']) {
      expect(allText.contains(lie), isFalse,
          reason: '🔴 the copy implies "$lie" — a driver who believes they '
              'cancelled and drives off has abandoned a live job');
    }
  });

  // ── COMMS LIVENESS — the row STAYS LIVE in motion, and is NOT wrapped ────
  //
  // 🔴 This is the lane-local twin of 15-00's gate side B. The gate walks the
  // phase's PRIMARY action; the comms row (Chat / Call / I'm stuck) is a
  // SEPARATE set of one-tap controls, and nothing in 15-00 asserts they survive
  // at speed. So the "do NOT wrap the comms row in TypingLockedInMotion"
  // invariant is machine-checked HERE, in the lane that owns it — otherwise
  // wrapping the row (a defect the brief explicitly forbids) would pass every
  // gate silently.
  group('🔴 the comms row stays live in motion (never text-locked)', () {
    testWidgets('Chat / Call / I\'m stuck are present and enabled at 30 mph',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          motionInteractorProvider.overrideWith(() => _PinnedMotion(true)),
          tripRunnerInteractorProvider
              .overrideWith2((id) => _PhaseRunner(TripPhase.arrivedAtPickup)),
          tripMapInteractorProvider.overrideWith2((id) => _StubMap()),
        ],
        child: MaterialApp(
          theme: HoppinTheme.driverDark(),
          home: const TripRunnerRiblet(rideId: rideId),
        ),
      ));
      await bounded(tester);

      for (final label in ['Chat', 'Call', "I'm stuck"]) {
        final button = find.widgetWithText(HopButton, label);
        expect(button, findsOneWidget,
            reason: '🔴 "$label" is GONE at speed — a cradled one-tap control '
                'is legal and it is how the job gets done. It must not be '
                'suppressed like a keyboard.');
        expect(tester.widget<HopButton>(button).onPressed, isNotNull,
            reason: '🔴 "$label" is present-but-disabled at speed, which is '
                'not available.');
      }
    });

    test('source: TripCommsRow is not wrapped in TypingLockedInMotion', () {
      final sources = scanDartSources()
          .where((s) => s.path.contains('/features/trip/'))
          .toList();
      final offenders = <String>[];
      for (final source in sources) {
        for (var i = 0; i < source.lines.length; i++) {
          if (source.lines[i].contains('TypingLockedInMotion') &&
              source.lines[i].contains('TripCommsRow')) {
            offenders.add('${source.path}:${i + 1}  ${source.lines[i].trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 the comms row is wrapped in the typing lock — that lock '
              'is for TEXT ENTRY ONLY:\n${offenders.join('\n')}');
    });
  });

  // ── S5 — the sheet has its OWN exit ─────────────────────────────────────
  testWidgets('S5 — closing the sheet lands back on the trip', (tester) async {
    await pumpRealRunner(tester, TripPhase.arrivedAtPickup);

    await tester.tap(find.widgetWithText(HopButton, "I'm stuck"));
    await bounded(tester);
    expect(find.byType(CancelUnavailableState), findsOneWidget);

    await tester.tap(find.widgetWithText(HopButton, 'Close'));
    await bounded(tester);

    expect(find.byType(CancelUnavailableState), findsNothing,
        reason: 'a disclosure that strands is only half-honest');
    // Back on the trip: the runner card is still there.
    expect(find.byKey(const ValueKey('trip-runner-card')), findsOneWidget);
  });
}

/// Runner pinned to a phase; lifecycle intents inert. `arrivedAt` is stamped so
/// the waiting surface renders at arrivedAtPickup.
class _PhaseRunner extends TripRunnerInteractor {
  _PhaseRunner(this.phase) : super('ride-1');

  final TripPhase phase;

  @override
  TripRunnerState build() => TripRunnerState(
        rideId: 'ride-1',
        phase: phase,
        arrivedAt: phase.index >= TripPhase.arrivedAtPickup.index
            ? DateTime.utc(2026, 7, 15, 9)
            : null,
      );

  @override
  Future<void> arrived() async {}

  @override
  Future<void> startTrip() async {}

  @override
  Future<void> complete() async {}

  @override
  void dismiss() {}
}

class _StubMap extends MapInteractor {
  _StubMap() : super('ride-1');

  @override
  MapState build() => const MapState();
}

/// The motion gate, pinned — the comms-liveness assertions are about the
/// INTERACTION BUDGET, not about geolocation.
class _PinnedMotion extends MotionInteractor {
  _PinnedMotion(this._inMotion);

  final bool _inMotion;

  @override
  MotionState build() => MotionState(
        inMotion: _inMotion,
        speedMps: _inMotion ? 13.4 : 0.0,
      );
}

/// A throwaway destination for the chat/call routes so `context.push` resolves.
class _StubDest extends StatelessWidget {
  const _StubDest(this.name);
  final String name;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('stub-$name')));
}

/// The recording bundle the harness hands back.
class _Recording {
  _Recording({required this.support, required this.rides});
  final _RecordingSupport support;
  final _RecordingRides rides;
}

/// Records support-ticket creation. Only the members the sheet touches exist.
class _RecordingSupport implements SupportRepository {
  int createCalls = 0;
  String? lastSubject;
  String? lastBody;
  String? lastRideId;

  @override
  Future<String> createTicket({
    required String subject,
    String? category,
    String? typeCode,
    String? priority,
    String? rideId,
    String? body,
    List<String>? tags,
  }) async {
    createCalls++;
    lastSubject = subject;
    lastBody = body;
    lastRideId = rideId;
    return 'ticket-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 🔴 Records cancel() so S3 can prove it is NEVER called. Every cancel 400s
/// (#1); the whole point is that this counter stays at zero.
class _RecordingRides implements RidesRepository {
  int cancelCalls = 0;

  @override
  Future<void> cancel({
    required String rideId,
    required String reasonId,
    required String canceledByUserId,
    required String actorType,
  }) async {
    cancelCalls++;
  }

  @override
  Future<Ride> getRide(String id) async => Ride(
        id: id,
        riderId: 'rider-1',
        driverId: 'driver-1',
        status: RideStatus.arriving,
      );

  @override
  Future<List<Ride>> history({int limit = 50}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
