// Acceptance tests for RouteStrip — the map-less journey identity
// (charge-line graft per 05-CONTEXT motif 2; rider-ux-patterns §6).
// Behaviour pumps under the rider light theme (the rider lane's show
// theme); the colour assertion loops all four HoppinTheme builders per the
// 05-02 convention. Bounded pumps only — the charge pulse loops forever,
// so settle-style pumping would hang.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

final Map<String, ThemeData> themes = <String, ThemeData>{
  'riderLight': HoppinTheme.riderLight(),
  'riderDark': HoppinTheme.riderDark(),
  'driverLight': HoppinTheme.driverLight(),
  'driverDark': HoppinTheme.driverDark(),
};

Future<void> pumpStrip(
  WidgetTester tester,
  Widget strip, {
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    MaterialApp(
      // Reuse ONE ThemeData instance across pumps — a fresh instance per
      // pump restarts AnimatedTheme and Material's implicit theme-change
      // animations, which would pollute the transient-callback assertions.
      theme: theme ?? themes['riderLight'],
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: strip)),
      ),
    ),
  );
}

RouteStrip strip({
  double progress = 0.4,
  String? waypoint,
  bool complete = false,
  bool showCarMarker = true,
}) {
  return RouteStrip(
    originLabel: 'Wolverhampton Rail Station',
    destinationLabel: 'New Cross Hospital',
    progress: progress,
    activeWaypoint: waypoint,
    complete: complete,
    showCarMarker: showCarMarker,
  );
}

/// The strip's single canvas — the CustomPaint inside its RepaintBoundary.
Finder stripCanvas() {
  return find.descendant(
    of: find.descendant(
      of: find.byType(RouteStrip),
      matching: find.byType(RepaintBoundary),
    ),
    matching: find.byType(CustomPaint),
  );
}

void main() {
  group('RouteStrip rendering', () {
    testWidgets('renders both node labels', (tester) async {
      await pumpStrip(tester, strip());
      expect(find.text('Wolverhampton Rail Station'), findsOneWidget);
      expect(find.text('New Cross Hospital'), findsOneWidget);
    });

    testWidgets('renders the active waypoint word when provided, hides when '
        'null', (tester) async {
      await pumpStrip(tester, strip(waypoint: 'Passing Heath Town'));
      expect(find.text('Passing Heath Town'), findsOneWidget);

      await pumpStrip(tester, strip());
      // Let the switcher's outgoing fade finish (bounded).
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Passing Heath Town'), findsNothing);
    });
  });

  group('RouteStrip animation', () {
    testWidgets('animates without exceptions on one canvas layer', (
      tester,
    ) async {
      await pumpStrip(tester, strip(progress: 0.4));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
      expect(stripCanvas(), findsOneWidget);
      expect(
        tester.binding.transientCallbackCount,
        greaterThan(0),
        reason: 'the charge pulse must be live mid-trip',
      );
    });

    testWidgets('progress changes tween smoothly', (tester) async {
      await pumpStrip(tester, strip(progress: 0.2));
      await tester.pump(const Duration(milliseconds: 32));

      await pumpStrip(tester, strip(progress: 0.6));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('RouteStrip completion bloom', () {
    testWidgets('bloom fires once on completion and never re-triggers', (
      tester,
    ) async {
      await pumpStrip(tester, strip(progress: 0.9));
      await tester.pump(const Duration(milliseconds: 32));

      await pumpStrip(tester, strip(progress: 0.9, complete: true));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.binding.transientCallbackCount,
        greaterThan(0),
        reason: 'the bloom must be in flight right after the flip',
      );
      // Pump through ~750ms — past the bloom and the fill retarget.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(tester.takeException(), isNull);
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'a completed strip goes quiet — bloom done, pulse resting',
      );

      // Idempotent: re-supplying the same complete value must not
      // re-trigger the bloom or wake any loop.
      await pumpStrip(tester, strip(progress: 0.9, complete: true));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('mounting already-complete does not bloom (the receipt '
        'case)', (tester) async {
      await pumpStrip(
        tester,
        strip(progress: 1, complete: true, showCarMarker: false),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'an already-complete strip renders statically — no bloom '
            'replay, no pulse',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('RouteStrip hygiene', () {
    testWidgets('no Opacity widget in the subtree', (tester) async {
      await pumpStrip(tester, strip(waypoint: 'Passing Heath Town'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byType(RouteStrip),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });
  });

  group('RouteStrip colour', () {
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('painter takes fill and track from the theme tokens '
          '($name)', (tester) async {
        await pumpStrip(tester, strip(), theme: theme);
        final painter =
            tester.widget<CustomPaint>(stripCanvas()).painter!
                as RouteStripPainter;
        final colors = theme.extension<HoppinColors>()!;
        expect(painter.accent, colors.accent);
        expect(painter.track, colors.hairline);
      });
    }
  });
}
