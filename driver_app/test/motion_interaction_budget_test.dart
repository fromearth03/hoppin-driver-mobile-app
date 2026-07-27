import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/motion/motion_builder.dart';
import 'package:hoppin_driver/features/trip/map/map_builder.dart';
import 'package:hoppin_driver/features/trip/map/map_interactor.dart';
import 'package:hoppin_driver/features/trip/map/map_state.dart';
import 'package:hoppin_driver/features/trip/trip_runner_builder.dart';
import 'package:hoppin_driver/features/trip/trip_runner_interactor.dart';
import 'package:hoppin_driver/features/trip/trip_runner_state.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import 'support/source_scan.dart';

/// 🔴 THE INTERACTION BUDGET. THE GATE HAS TWO SIDES AND BOTH MUST BE ABLE TO
/// FAIL.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE LAW, AS CORRECTED. Read this before you change a line of this file.
/// ─────────────────────────────────────────────────────────────────────────
///
/// An earlier draft of this milestone's own documents claimed "any handheld
/// device use while driving is an offence, even when stationary at lights", and
/// used it to argue for banning interaction on the trip runner outright. **That
/// was wrong on the law.** It was corrected on 2026-07-14, and building to it
/// would have shipped a driver app that cannot do the driver's job.
///
/// **The offence is HOLDING the device.** A phone in a cradle is legal, and
/// TOUCHING ITS SCREEN while cradled is not the offence. Taxi and PHV drivers
/// are explicitly permitted cradled and hands-free use to accept bookings and
/// take calls. That is precisely how every Uber, Bolt and FreeNow driver
/// legally taps Accept, Arrived and Start Trip — no special exemption was ever
/// needed, because mounted use was never the offence.
///
/// What still bites is **driving without due care** if an interaction distracts
/// — and for a PHV driver that feeds the council's "fit and proper person"
/// test. So the constraint is **GLANCEABILITY, NOT ABSTINENCE**, and the single
/// least glanceable thing in any app is **a keyboard**.
///
/// ─────────────────────────────────────────────────────────────────────────
/// SIDE A — the suppression. What must be GONE at speed.
///   A1  No TextField / TextFormField reachable from the trip runner.
///   A2  No >2-tap flow reachable.
///   A3  No modal AUTO-PRESENTS over the driving surface (SF-04).
///
/// SIDE B — the availability. What must REMAIN at speed. NOT OPTIONAL.
///   B1  The phase's primary action is present AND ENABLED. A driver at 30 mph
///       approaching a pickup must still be able to tap Arrived.
///   B2  The chat template chips stay live. Templates-first exists precisely so
///       the keyboard is never needed.
///   B3  The composer RETURNS when stopped. A gate that never opens is not a
///       gate; it is a deletion.
///
/// 🔴 A gate that only checked side A would be fully satisfied by an app with
/// no controls at all — and that app is a WORSE app. It forces the driver to
/// pull over to do a thing the law lets them do at the wheel, and it will be
/// uninstalled.
/// ─────────────────────────────────────────────────────────────────────────
void main() {
  const TripRiderContext sophie = (
    name: 'Sophie Bell',
    rating: 4.8,
    pickupLabel: 'Wolverhampton Rail Station',
    pickupEtaSeconds: 120,
  );

  TripRunnerState stateFor(TripPhase phase) => TripRunnerState(
        rideId: 'ride-1',
        phase: phase,
        etaSeconds: phase == TripPhase.headingToPickup ? 90 : null,
        riderContext: sophie,
      );

  /// Bounded pumps only — NEVER `pumpAndSettle`. The driver app has live
  /// polling providers and settle-detection never terminates. Standing project
  /// convention.
  Future<void> bounded(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Boots the REAL trip runner with the motion gate pinned.
  Future<void> pumpRunner(
    WidgetTester tester, {
    required bool inMotion,
    TripPhase phase = TripPhase.headingToPickup,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        motionInteractorProvider.overrideWith(() => _PinnedMotion(inMotion)),
        tripRunnerInteractorProvider
            .overrideWith2((rideId) => _StubRunner(stateFor(phase))),
        tripMapInteractorProvider.overrideWith2((rideId) => _StubMap()),
      ],
      child: MaterialApp(
        // The driver's PRIMARY theme (SF-02).
        theme: HoppinTheme.driverDark(),
        home: const TripRunnerRiblet(rideId: 'ride-1'),
      ),
    ));
    await bounded(tester);
  }

  // ───────────────────────── SIDE A — the suppression ─────────────────────

  group('🔴 SIDE A — no TYPING reachable in motion', () {
    testWidgets(
        'A1 — no TextField is reachable from the trip runner at speed, at any '
        'phase, behind any control', (tester) async {
      for (final phase in TripPhase.values) {
        await pumpRunner(tester, inMotion: true, phase: phase);

        expect(
          find.byType(TextField),
          findsNothing,
          reason: 'a TextField is on the driving surface at $phase. A keyboard '
              'is the least glanceable thing in the app.',
        );
        expect(find.byType(TextFormField), findsNothing);

        // Walk EVERY reachable control and look again after each. This is the
        // net that catches a text field hidden one tap deep.
        final controls = <Finder>[
          find.byType(InkWell),
          find.byType(GestureDetector),
          find.byType(HopButton),
          find.byType(IconButton),
        ];
        for (final control in controls) {
          final count = tester.widgetList(control).length;
          for (var i = 0; i < count; i++) {
            final target = control.at(i);
            if (!tester.any(target)) continue;
            try {
              await tester.tap(target, warnIfMissed: false);
            } catch (_) {
              // An off-screen or un-hittable control is not reachable by the
              // driver either. Skip it; it cannot present a keyboard.
              continue;
            }
            await bounded(tester);
            expect(
              find.byType(TextField),
              findsNothing,
              reason: 'tapping a control at $phase revealed a TextField while '
                  'the vehicle is moving',
            );
            expect(find.byType(TextFormField), findsNothing);
          }
        }
      }
    });

    testWidgets('A3 — NO MODAL AUTO-PRESENTS over the windscreen (SF-04)',
        (tester) async {
      for (final phase in TripPhase.values) {
        await pumpRunner(tester, inMotion: true, phase: phase);
        await bounded(tester);
        await bounded(tester);

        expect(
          find.byType(BottomSheet),
          findsNothing,
          reason: 'a sheet arrived over the driving surface at $phase without '
              'the driver asking for it',
        );
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
      }
    });
  });

  group('🔴 SIDE A — the source-level net (comment-stripped)', () {
    test(
        'A2 — no >2-tap flow: no trip-surface source pushes a route deeper '
        'than one level below /trip/:id', () {
      final sources = scanDartSources();
      expect(sources, isNotEmpty, reason: 'the sweep must sweep something');

      final surface = sources.where(
        (s) => s.path.contains('/features/trip/') ||
            s.path.contains('/features/motion/'),
      );
      expect(surface, isNotEmpty);

      final offenders = <String>[];
      final deepPush = RegExp(r"""(go|push)\(\s*['"]/trip/[^'"]*/[^'"]*/""");
      for (final source in surface) {
        for (var i = 0; i < source.lines.length; i++) {
          if (deepPush.hasMatch(source.lines[i])) {
            offenders.add('${source.path}:${i + 1}  ${source.lines[i].trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'a flow more than one level below /trip/:id is reachable from '
            'the driving surface:\n${offenders.join('\n')}',
      );
    });

    test(
        '🔴 A1-source — the ONLY TextField under features/trip|motion is '
        'wrapped in TypingLockedInMotion', () {
      // The widget-tree walk above can only see what the current fixtures
      // render. This net catches a TextField added behind a state the fixtures
      // do not reach — and it runs over COMMENT-STRIPPED source, so a doc
      // comment explaining the ban is never mistaken for the ban being broken.
      final sources = scanDartSources();
      final surface = sources.where(
        (s) =>
            s.path.contains('/features/trip/') ||
            s.path.contains('/features/motion/'),
      );

      final offenders = <String>[];
      for (final source in surface) {
        if (!source.text.contains('TextField(')) continue;
        // A file may hold a TextField ONLY if the same file hands it to the
        // lock. (The lock's own widget file is exempt: it holds no TextField,
        // it removes one.)
        if (!source.text.contains('TypingLockedInMotion')) {
          for (var i = 0; i < source.lines.length; i++) {
            if (source.lines[i].contains('TextField(')) {
              offenders
                  .add('${source.path}:${i + 1}  ${source.lines[i].trim()}');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'an UNGUARDED TextField sits on the driving surface. Wrap it '
            'in TypingLockedInMotion:\n${offenders.join('\n')}',
      );
    });

    test(
        '🔴 the lock REMOVES rather than disables — no IgnorePointer, no '
        'AbsorbPointer, no `enabled: false` in features/motion', () {
      // A disabled TextField is STILL a TextField. It exists, a driver taps it,
      // a caret appears, and A1 finds it. The keyboard has to be GONE.
      final motion = scanDartSources()
          .where((s) => s.path.contains('/features/motion/'))
          .toList();
      expect(motion, isNotEmpty, reason: 'features/motion must exist');

      final offenders = <String>[];
      for (final source in motion) {
        for (var i = 0; i < source.lines.length; i++) {
          final line = source.lines[i];
          if (line.contains('IgnorePointer') ||
              line.contains('AbsorbPointer') ||
              line.contains('enabled: false')) {
            offenders.add('${source.path}:${i + 1}  ${line.trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'the lock DISABLES instead of REMOVING. A disabled TextField '
            'is still a TextField:\n${offenders.join('\n')}',
      );
    });
  });

  // ───────────────────────── SIDE B — the availability ────────────────────

  group('🔴 SIDE B — the driver KEEPS their controls at speed', () {
    testWidgets(
        'B1 — Arrived at pickup is PRESENT and ENABLED at 30 mph',
        (tester) async {
      await pumpRunner(
        tester,
        inMotion: true,
        phase: TripPhase.headingToPickup,
      );

      final button = find.widgetWithText(HopButton, 'Arrived');
      expect(
        button,
        findsOneWidget,
        reason: '🔴 THE ARRIVED BUTTON IS GONE AT SPEED. A driver approaching '
            'a pickup must still be able to tap it — that is how every '
            'competitor works and it is legal from a cradle. An app that '
            'removes it forces the driver to pull over to do a legal thing.',
      );
      expect(
        tester.widget<HopButton>(button).onPressed,
        isNotNull,
        reason: '🔴 THE ARRIVED BUTTON IS DISABLED AT SPEED. '
            'Present-but-disabled is NOT available.',
      );
    });

    testWidgets('B1 — the start slider is PRESENT and ENABLED in motion',
        (tester) async {
      await pumpRunner(
        tester,
        inMotion: true,
        phase: TripPhase.arrivedAtPickup,
      );

      final slider = find.byType(SlideToConfirm);
      expect(slider, findsOneWidget, reason: 'the start slider vanished at speed');
      expect(
        tester.widget<SlideToConfirm>(slider).enabled,
        isTrue,
        reason: '🔴 the start slider is disabled in motion. Present-but-'
            'disabled is not available.',
      );
    });

    testWidgets('B1 — the complete slider is PRESENT and ENABLED in motion',
        (tester) async {
      await pumpRunner(tester, inMotion: true, phase: TripPhase.inTrip);

      final slider = find.byType(SlideToConfirm);
      expect(slider, findsOneWidget,
          reason: 'the complete slider vanished at speed');
      expect(
        tester.widget<SlideToConfirm>(slider).enabled,
        isTrue,
        reason: '🔴 the complete slider is disabled in motion.',
      );
    });

    testWidgets('B1 — the Arrived intent actually FIRES at speed',
        (tester) async {
      // Present + enabled is not enough: the tap must reach the interactor. A
      // swallowed tap is a disabled button wearing a costume.
      await tester.pumpWidget(ProviderScope(
        overrides: [
          motionInteractorProvider.overrideWith(() => _PinnedMotion(true)),
          tripRunnerInteractorProvider
              .overrideWith2((rideId) => _StubRunner(stateFor(TripPhase.headingToPickup))),
          tripMapInteractorProvider.overrideWith2((rideId) => _StubMap()),
        ],
        child: MaterialApp(
          theme: HoppinTheme.driverDark(),
          home: const TripRunnerRiblet(rideId: 'ride-1'),
        ),
      ));
      await bounded(tester);

      await tester.tap(find.widgetWithText(HopButton, 'Arrived'));
      await bounded(tester);

      expect(
        _StubRunner.lastArrivedCalls,
        1,
        reason: '🔴 the tap did not reach the interactor at speed. The button '
            'is disabled in all but appearance.',
      );
    });
  });

  group('🔴 SIDE B — the cross-lane assertions (15-01 turns these green)', () {
    // 🔴 THESE ARE DELIBERATELY LEFT RED IN WAVE 1 AND THAT IS CORRECT.
    //
    // The chat surface does not exist yet — lane 15-01 builds it. Weakening
    // these to make wave 1 look clean would remove the ONLY thing standing
    // between 15-01 and a chat that either (a) hands a moving driver a
    // keyboard, or (b) takes their quick replies away and leaves them with no
    // way to tell the rider anything at all.
    //
    // They are written now, `skip: false`, and 15-01 turns them green.

    test(
        'B2 — the chat TEMPLATE CHIPS exist and are NOT wrapped in the typing '
        'lock', () {
      final sources = scanDartSources();
      final templates = sources.where(
        (s) => s.text.contains('DriverChatTemplates'),
      );

      expect(
        templates,
        isNotEmpty,
        reason: '🔴 EXPECTED RED UNTIL 15-01 LANDS. DriverChatTemplates does '
            'not exist yet. Templates-first is why the keyboard is never '
            'needed at speed — without them, side A leaves the driver mute.',
      );

      // When it lands: the chips must NOT be inside the lock. Wrapping a
      // one-tap control in TypingLockedInMotion is a defect — the lock is for
      // TEXT ENTRY ONLY.
      for (final source in templates) {
        final lines = source.lines;
        for (var i = 0; i < lines.length; i++) {
          if (!lines[i].contains('TypingLockedInMotion')) continue;
          final window = lines
              .sublist(i, (i + 12).clamp(0, lines.length))
              .join('\n');
          expect(
            window.contains('DriverChatTemplates'),
            isFalse,
            reason: '🔴 the template chips are wrapped in TypingLockedInMotion '
                'at ${source.path}:${i + 1}. The chips are a ONE-TAP control '
                'and they STAY LIVE at speed — they are the entire reason the '
                'keyboard is never needed.',
          );
        }
      }
    });

    test(
        'B3 — the composer RETURNS when stopped: a TextField exists in the '
        'chat surface, guarded by the lock rather than deleted', () {
      final sources = scanDartSources();
      final guarded = sources.where(
        (s) =>
            s.text.contains('TypingLockedInMotion') &&
            s.text.contains('TextField('),
      );

      expect(
        guarded,
        isNotEmpty,
        reason: '🔴 EXPECTED RED UNTIL 15-01 LANDS. No composer is GUARDED by '
            'TypingLockedInMotion anywhere. A gate that never opens is not a '
            'gate — it is a deletion. The driver must get their keyboard back '
            'the moment they stop.',
      );
    });
  });
}

/// The gate, pinned. Every lane consumes `motionInteractorProvider`; this
/// overrides it rather than scripting GPS, so the assertions are about the
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

class _StubRunner extends TripRunnerInteractor {
  _StubRunner(this.fixture) : super('ride-1') {
    lastArrivedCalls = 0;
  }

  final TripRunnerState fixture;

  /// Static because the tree is rebuilt per-pump and the test reads the count
  /// after the widget has been disposed and rebuilt.
  static int lastArrivedCalls = 0;

  @override
  TripRunnerState build() => fixture;

  @override
  Future<void> arrived() async {
    lastArrivedCalls++;
  }

  @override
  Future<void> startTrip() async {}

  @override
  Future<void> complete() async {}
}

/// Hermetic map: hidden canvas, no geo seams, no poll timer.
class _StubMap extends MapInteractor {
  _StubMap() : super('ride-1');

  @override
  MapState build() => const MapState();
}
