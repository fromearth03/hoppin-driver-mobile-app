import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/features/motion/motion_builder.dart';
import 'package:hoppin_driver/features/motion/widgets/typing_locked_in_motion.dart';
import 'package:hoppin_driver/features/rating/rider_rating_sheet.dart';
import 'package:hoppin_shared/hoppin_shared.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

/// 🔴 THE DRIVER RATES THE RIDER — BOUND SINCE DAY ONE, ZERO UI UNTIL NOW —
/// AND IT IS MOTION-GATED, SKIPPABLE, AND NEVER A TOLL GATE.
///
///   RR1  it posts: 4 stars → rate(rideId:, score: 4) fires exactly once.
///   RR2  🔴 UNREACHABLE IN MOTION (OT-14): no sheet, no auto-modal at speed;
///        it becomes available — deferred, not destroyed — when stopped.
///   RR3  the comment box is text entry → wrapped in TypingLockedInMotion.
///   RR4  🔴 skippable, and skipping NEVER gates the exit.
///   RR5  a failed post does not trap the driver — an honest line, still can
///        leave.
///
/// Bounded pumps only — NEVER `pumpAndSettle`.
void main() {
  Future<void> bounded(WidgetTester tester, [int times = 5]) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('RR1 — pick 4 stars and submit → rate(score: 4) fires once',
      (tester) async {
    final rides = _RecordingRidesRepo();
    await tester.pumpWidget(_boot(rides: rides, child: const _SheetHost()));
    await bounded(tester);

    await tester.tap(find.text('Open rating'));
    await bounded(tester);

    // Pick the 4th star.
    final stars = find.byIcon(Icons.star_border);
    expect(stars, findsWidgets, reason: 'the star picker renders');
    await tester.tap(find.byKey(const Key('rider-rating-star-4')));
    await bounded(tester);

    await tester.tap(find.widgetWithText(HopButton, 'Submit rating'));
    await bounded(tester);

    expect(rides.rateCalls, 1, reason: 'exactly one POST');
    expect(rides.lastScore, 4);
    expect(rides.lastRideId, 'ride-1');
  });

  testWidgets('RR2 — UNREACHABLE IN MOTION: no sheet, no auto-modal at speed; '
      'available when stopped', (tester) async {
    final motion = _PinnedMotion(true);
    await tester.pumpWidget(_boot(
      motion: () => motion,
      // The gate is mounted on the COMPLETED trip surface.
      child: const RiderRatingGate(rideId: 'ride-1', active: true),
    ));
    await bounded(tester);

    // 🔴 SF-04: nothing auto-presents over a moving windscreen.
    expect(find.byType(BottomSheet), findsNothing,
        reason: '🔴 a rating sheet is sustained attention over a moving '
            'windscreen — the exact due-care hazard the budget is about');
    expect(find.byType(RiderRatingSheetView), findsNothing);

    // Stop the vehicle: the sheet becomes available — deferred, not destroyed.
    motion.setInMotion(false);
    await bounded(tester, 8);

    expect(find.byType(RiderRatingSheetView), findsOneWidget,
        reason: 'the sheet was HELD while moving and presents at the next idle '
            'moment — never lost');
  });

  testWidgets('RR3 — the comment box is text entry, wrapped in the lock',
      (tester) async {
    await tester.pumpWidget(_boot(child: const _SheetHost()));
    await bounded(tester);
    await tester.tap(find.text('Open rating'));
    await bounded(tester);

    // The comment field exists AND is guarded by the typing lock.
    expect(find.byType(TypingLockedInMotion), findsOneWidget,
        reason: 'the optional comment IS text entry — it must be wrapped so a '
            'future refactor cannot smuggle a keyboard onto a moving screen');
    expect(
      find.descendant(
        of: find.byType(TypingLockedInMotion),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
  });

  testWidgets('RR4 — skippable, and skipping NEVER gates the exit',
      (tester) async {
    final rides = _RecordingRidesRepo();
    await tester.pumpWidget(_boot(rides: rides, child: const _SheetHost()));
    await bounded(tester);
    await tester.tap(find.text('Open rating'));
    await bounded(tester);

    // Dismiss WITHOUT rating.
    await tester.tap(find.widgetWithText(HopButton, 'Skip'));
    await bounded(tester);

    expect(find.byType(RiderRatingSheetView), findsNothing,
        reason: 'skipping closes the sheet');
    expect(rides.rateCalls, 0,
        reason: '🔴 skipping is normal — it never posts and it is never a '
            'failure. The rating is offered, never a toll gate.');
    // The host is still there — the flow did not trap or crash on the skip.
    expect(find.text('Open rating'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RR5 — a failed post does not trap the driver', (tester) async {
    final rides = _RecordingRidesRepo()..throwOnRate = true;
    await tester.pumpWidget(_boot(rides: rides, child: const _SheetHost()));
    await bounded(tester);
    await tester.tap(find.text('Open rating'));
    await bounded(tester);

    await tester.tap(find.byKey(const Key('rider-rating-star-5')));
    await bounded(tester);
    await tester.tap(find.widgetWithText(HopButton, 'Submit rating'));
    await bounded(tester);

    expect(rides.rateCalls, 1);
    // An honest line, and the driver can STILL leave (the Skip exit survives).
    expect(find.widgetWithText(HopButton, 'Skip'), findsOneWidget,
        reason: '🔴 a failed rating never traps the driver — the exit stays');
    await tester.tap(find.widgetWithText(HopButton, 'Skip'));
    await bounded(tester);
    expect(find.byType(RiderRatingSheetView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// Boots a hermetic MaterialApp with the rating dependencies overridden.
Widget _boot({
  required Widget child,
  _RecordingRidesRepo? rides,
  MotionInteractor Function()? motion,
}) {
  return ProviderScope(
    overrides: [
      ridesRepositoryProvider.overrideWithValue(rides ?? _RecordingRidesRepo()),
      if (motion != null) motionInteractorProvider.overrideWith(motion),
    ],
    child: MaterialApp(
      // The driver's PRIMARY theme (SF-02).
      theme: HoppinTheme.driverDark(),
      home: Scaffold(body: child),
    ),
  );
}

/// A trivial host with a button that opens the rating sheet — stands in for
/// the completed-trip card that (in 15-03) presents it.
class _SheetHost extends ConsumerWidget {
  const _SheetHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: HopButton.primary(
        label: 'Open rating',
        onPressed: () => showRiderRatingSheet(context, rideId: 'ride-1'),
      ),
    );
  }
}

/// The gate, pinned to a scripted motion state (30 mph ≈ 13.4 m/s).
class _PinnedMotion extends MotionInteractor {
  _PinnedMotion(this._inMotion);

  bool _inMotion;

  void setInMotion(bool value) {
    _inMotion = value;
    state = MotionState(inMotion: value, speedMps: value ? 13.4 : 0.0);
  }

  @override
  MotionState build() =>
      MotionState(inMotion: _inMotion, speedMps: _inMotion ? 13.4 : 0.0);
}

/// Records the one BOUND rating post and can be armed to throw.
class _RecordingRidesRepo implements RidesRepository {
  int rateCalls = 0;
  int? lastScore;
  String? lastRideId;
  String? lastComments;
  bool throwOnRate = false;

  @override
  Future<void> rate({
    required String rideId,
    required int score,
    String? comments,
  }) async {
    rateCalls++;
    lastRideId = rideId;
    lastScore = score;
    lastComments = comments;
    if (throwOnRate) {
      throw const ApiException(statusCode: 500, message: 'Server error');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
