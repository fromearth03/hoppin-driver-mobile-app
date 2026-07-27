// Acceptance tests for RadarPulse — the matching-state radar
// (flutter-web-feasibility §3: one painter, phase-offset rings, paint-alpha
// fades). Behaviour pumps under the rider light theme; the colour assertion
// loops all four HoppinTheme builders per the 05-02 convention. Bounded
// pumps only — the rings loop forever, so settle-style pumping would hang.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

final Map<String, ThemeData> themes = <String, ThemeData>{
  'riderLight': HoppinTheme.riderLight(),
  'riderDark': HoppinTheme.riderDark(),
  'driverLight': HoppinTheme.driverLight(),
  'driverDark': HoppinTheme.driverDark(),
};

Future<void> pumpRadar(
  WidgetTester tester,
  Widget radar, {
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    MaterialApp(
      // Reuse ONE ThemeData instance across pumps — a fresh instance per
      // pump restarts AnimatedTheme and would pollute ticker assertions.
      theme: theme ?? themes['riderLight'],
      home: Scaffold(body: Center(child: radar)),
    ),
  );
}

/// The radar's single canvas — the CustomPaint inside its RepaintBoundary.
Finder radarCanvas() {
  return find.descendant(
    of: find.descendant(
      of: find.byType(RadarPulse),
      matching: find.byType(RepaintBoundary),
    ),
    matching: find.byType(CustomPaint),
  );
}

void main() {
  group('RadarPulse sizing', () {
    testWidgets('renders at the default 160 square', (tester) async {
      await pumpRadar(tester, const RadarPulse());
      expect(tester.getSize(find.byType(RadarPulse)), const Size(160, 160));
    });

    testWidgets('respects a custom size', (tester) async {
      await pumpRadar(tester, const RadarPulse(size: 220));
      expect(tester.getSize(find.byType(RadarPulse)), const Size(220, 220));
    });
  });

  group('RadarPulse animation', () {
    testWidgets('animates continuously without exceptions on one canvas '
        'layer', (tester) async {
      await pumpRadar(tester, const RadarPulse());
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
      expect(radarCanvas(), findsOneWidget);
      expect(
        tester.binding.transientCallbackCount,
        greaterThan(0),
        reason: 'the radar loop must stay alive while mounted',
      );
    });

    testWidgets('ring count is configurable', (tester) async {
      await pumpRadar(tester, const RadarPulse(rings: 4));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(RadarPulse), findsOneWidget);
    });
  });

  group('RadarPulse hygiene', () {
    testWidgets('no Opacity widget in the subtree', (tester) async {
      await pumpRadar(tester, const RadarPulse());
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byType(RadarPulse),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });
  });

  group('RadarPulse colour', () {
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('rings stroke with the lane accent ($name)', (
        tester,
      ) async {
        await pumpRadar(tester, const RadarPulse(), theme: theme);
        final painter =
            tester.widget<CustomPaint>(radarCanvas()).painter!
                as RadarPulsePainter;
        expect(painter.accent, theme.extension<HoppinColors>()!.accent);
      });
    }
  });
}
