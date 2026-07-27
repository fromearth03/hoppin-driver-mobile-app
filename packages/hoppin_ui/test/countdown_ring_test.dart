// Acceptance tests for CountdownRing — the offer takeover's wall-clock
// countdown (driver-ux-motion §5 'Countdown ring', 03-CONTEXT colour
// policy). The ring must derive PURELY from clock.now(): every case pins
// the wall clock with withClock(Clock.fixed(t)) and proves the fraction is
// frame-count independent. Bounded pumps only — the frame driver loops.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

final Map<String, ThemeData> themes = <String, ThemeData>{
  'riderLight': HoppinTheme.riderLight(),
  'riderDark': HoppinTheme.riderDark(),
  'driverLight': HoppinTheme.driverLight(),
  'driverDark': HoppinTheme.driverDark(),
};

final DateTime start = DateTime(2026, 7, 7, 12);
final DateTime deadline = start.add(const Duration(seconds: 45));

Widget harness(ThemeData theme, Widget child) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: Center(child: child)),
  );
}

CountdownRingPainter painterOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(CountdownRing),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CountdownRingPainter,
      ),
    ),
  );
  return paint.painter! as CountdownRingPainter;
}

void main() {
  group('CountdownRing fraction', () {
    testWidgets('is wall-clock-derived, independent of frames elapsed', (
      tester,
    ) async {
      await withClock(Clock.fixed(start.add(const Duration(seconds: 15))), () async {
        await tester.pumpWidget(
          harness(
            HoppinTheme.driverDark(),
            CountdownRing(deadline: deadline, startedAt: start),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(painterOf(tester).debugLastFraction, closeTo(30 / 45, 0.01));
      });

      // Jump the wall clock 25s while pumping only ONE 16ms frame — the
      // fraction must land on the correct remaining arc regardless of how
      // few frames elapsed (the pause/throttle self-correction proof).
      await withClock(Clock.fixed(start.add(const Duration(seconds: 40))), () async {
        await tester.pump(const Duration(milliseconds: 16));
        expect(painterOf(tester).debugLastFraction, closeTo(5 / 45, 0.01));
      });
    });

    testWidgets('clamps to 0 at/after the deadline — never negative', (
      tester,
    ) async {
      await withClock(Clock.fixed(start.add(const Duration(seconds: 50))), () async {
        await tester.pumpWidget(
          harness(
            HoppinTheme.driverDark(),
            CountdownRing(deadline: deadline, startedAt: start),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(painterOf(tester).debugLastFraction, 0.0);
        expect(find.text('0'), findsOneWidget);
      });
    });
  });

  group('CountdownRing seconds', () {
    testWidgets('shows ceil(remaining): 29.8s left renders 30', (
      tester,
    ) async {
      await withClock(
        Clock.fixed(start.add(const Duration(milliseconds: 15200))),
        () async {
          await tester.pumpWidget(
            harness(
              HoppinTheme.driverDark(),
              CountdownRing(deadline: deadline, startedAt: start),
            ),
          );
          expect(find.text('30'), findsOneWidget);
        },
      );
    });

    testWidgets('shows ceil(remaining): 0.6s left renders 1', (tester) async {
      await withClock(
        Clock.fixed(start.add(const Duration(milliseconds: 44400))),
        () async {
          await tester.pumpWidget(
            harness(
              HoppinTheme.driverDark(),
              CountdownRing(deadline: deadline, startedAt: start),
            ),
          );
          expect(find.text('1'), findsOneWidget);
        },
      );
    });
  });

  group('CountdownRing colour policy (§5: warn at ~40% left, error at ~15%)',
      () {
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets(
          'accent above 40%, warn band between 40% and 15%, '
          'error below 15% ($name)', (tester) async {
        final colors = theme.extension<HoppinColors>()!;

        // 25s elapsed → 20s remaining = 44% of the 45s window: accent.
        await withClock(Clock.fixed(start.add(const Duration(seconds: 25))), () async {
          await tester.pumpWidget(
            harness(
              theme,
              CountdownRing(deadline: deadline, startedAt: start),
            ),
          );
          await tester.pump(const Duration(milliseconds: 16));
          expect(painterOf(tester).debugLastStrokeColor, colors.accent);
        });

        // 28s elapsed → 17s remaining = 38%: inside the warn→error ramp.
        await withClock(Clock.fixed(start.add(const Duration(seconds: 28))), () async {
          await tester.pump(const Duration(milliseconds: 16));
          final stroke = painterOf(tester).debugLastStrokeColor;
          expect(
            stroke,
            isNot(colors.accent),
            reason: '38% remaining must have left accent for the warn ramp',
          );
          expect(
            stroke,
            isNot(colors.error),
            reason: '38% remaining must not have reached full error yet',
          );
        });

        // 41s elapsed → 4s remaining = 9% (< 15%): solid error.
        await withClock(Clock.fixed(start.add(const Duration(seconds: 41))), () async {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            painterOf(tester).debugLastStrokeColor,
            colors.error,
            reason: 'below 15% remaining the stroke holds the error role',
          );
        });
      });
    }
  });

  group('CountdownRing composition', () {
    testWidgets('child composes with the seconds — never ring alone', (
      tester,
    ) async {
      await withClock(Clock.fixed(start.add(const Duration(seconds: 15))), () async {
        await tester.pumpWidget(
          harness(
            HoppinTheme.driverDark(),
            CountdownRing(
              deadline: deadline,
              startedAt: start,
              child: const Text('Accept'),
            ),
          ),
        );
        expect(find.text('Accept'), findsOneWidget);
        expect(find.text('30'), findsOneWidget);
      });
    });

    testWidgets('inner content breathes in the final 3s', (tester) async {
      await withClock(Clock.fixed(start.add(const Duration(seconds: 43))), () async {
        await tester.pumpWidget(
          harness(
            HoppinTheme.driverDark(),
            CountdownRing(deadline: deadline, startedAt: start),
          ),
        );
        double breatheScale() => tester
            .widget<ScaleTransition>(
              find.descendant(
                of: find.byType(CountdownRing),
                matching: find.byType(ScaleTransition),
              ),
            )
            .scale
            .value;
        final before = breatheScale();
        await tester.pump(const Duration(milliseconds: 250));
        expect(breatheScale(), isNot(before));
      });
    });

    testWidgets('a RepaintBoundary isolates the ring, no Opacity anywhere', (
      tester,
    ) async {
      await withClock(Clock.fixed(start.add(const Duration(seconds: 15))), () async {
        await tester.pumpWidget(
          harness(
            HoppinTheme.driverDark(),
            CountdownRing(deadline: deadline, startedAt: start),
          ),
        );
        expect(
          find.descendant(
            of: find.byType(CountdownRing),
            matching: find.byType(RepaintBoundary),
          ),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: find.byType(CountdownRing),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
      });
    });
  });
}
