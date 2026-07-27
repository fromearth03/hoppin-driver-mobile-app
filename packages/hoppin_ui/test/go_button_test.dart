// Acceptance tests for GoButton — the driver dashboard's go-online
// affordance (driver-ux-motion §5 'Go button pulse'). Behaviour pumps under
// the driver dark theme (the show theme); the colour assertion loops all
// four HoppinTheme builders per the 05-02 convention. Bounded pumps only —
// the offline pulse loops forever, so settle-style pumping would hang.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

final Map<String, ThemeData> themes = <String, ThemeData>{
  'riderLight': HoppinTheme.riderLight(),
  'riderDark': HoppinTheme.riderDark(),
  'driverLight': HoppinTheme.driverLight(),
  'driverDark': HoppinTheme.driverDark(),
};

Future<void> pumpUnder(WidgetTester tester, ThemeData theme, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Every ScaleTransition scale value inside the button, captured now.
List<double> scalesOf(WidgetTester tester) {
  return tester
      .widgetList<ScaleTransition>(
        find.descendant(
          of: find.byType(GoButton),
          matching: find.byType(ScaleTransition),
        ),
      )
      .map((w) => w.scale.value)
      .toList();
}

void main() {
  group('GoButton offline', () {
    testWidgets('shows GO and breathes (scale changes between instants)', (
      tester,
    ) async {
      await pumpUnder(
        tester,
        HoppinTheme.driverDark(),
        GoButton(onPressed: () {}, online: false),
      );
      expect(find.text('GO'), findsOneWidget);

      final before = scalesOf(tester);
      await tester.pump(const Duration(milliseconds: 400));
      final after = scalesOf(tester);
      expect(before.length, after.length);
      expect(before, isNot(equals(after)), reason: 'the breath must move');
    });

    testWidgets('tap fires onPressed exactly once', (tester) async {
      var presses = 0;
      await pumpUnder(
        tester,
        HoppinTheme.driverDark(),
        GoButton(onPressed: () => presses++, online: false),
      );
      await tester.tap(find.byType(GoButton));
      await tester.pump(const Duration(milliseconds: 150));
      expect(presses, 1);
    });

    testWidgets('busy swallows taps', (tester) async {
      var presses = 0;
      await pumpUnder(
        tester,
        HoppinTheme.driverDark(),
        GoButton(onPressed: () => presses++, online: false, busy: true),
      );
      await tester.tap(find.byType(GoButton), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 150));
      expect(presses, 0);
    });
  });

  group('GoButton online', () {
    testWidgets('GO gone, online affordance present, no looping pulse', (
      tester,
    ) async {
      await pumpUnder(
        tester,
        HoppinTheme.driverDark(),
        GoButton(onPressed: () {}, online: true),
      );
      // Let any entrance settle within bounds.
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('GO'), findsNothing);
      expect(find.text('Online'), findsOneWidget);

      final before = scalesOf(tester);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final after = scalesOf(tester);
      expect(before, equals(after), reason: 'online must be quiet — no loop');
    });
  });

  group('GoButton hygiene', () {
    testWidgets('no Opacity widget anywhere in the subtree', (tester) async {
      await pumpUnder(
        tester,
        HoppinTheme.driverDark(),
        GoButton(onPressed: () {}, online: false),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byType(GoButton),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('a RepaintBoundary isolates the pulsing layer', (
      tester,
    ) async {
      await pumpUnder(
        tester,
        HoppinTheme.driverDark(),
        GoButton(onPressed: () {}, online: false),
      );
      expect(
        find.descendant(
          of: find.byType(GoButton),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });
  });

  group('GoButton colour', () {
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('offline circle fills with the lane accent ($name)', (
        tester,
      ) async {
        await pumpUnder(
          tester,
          theme,
          GoButton(onPressed: () {}, online: false),
        );
        final container = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byType(GoButton),
            matching: find.byType(AnimatedContainer),
          ),
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.shape, BoxShape.circle);
        expect(decoration.color, theme.extension<HoppinColors>()!.accent);
      });
    }
  });
}
