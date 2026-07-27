// Acceptance tests for SlideToConfirm — the drag-to-confirm slider for
// money-affecting trip transitions (driver-ux-motion §5 'Slide-to-advance').
// Springs back below ~70% travel, confirms exactly once past it, inert when
// disabled. Fixed-width harness; bounded pumps only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

final Map<String, ThemeData> themes = <String, ThemeData>{
  'riderLight': HoppinTheme.riderLight(),
  'riderDark': HoppinTheme.riderDark(),
  'driverLight': HoppinTheme.driverLight(),
  'driverDark': HoppinTheme.driverDark(),
};

Widget harness(ThemeData theme, Widget child) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  );
}

Finder get thumb => find.byIcon(Icons.chevron_right);

void main() {
  group('SlideToConfirm', () {
    testWidgets('sub-threshold release springs back, no confirm', (
      tester,
    ) async {
      var confirms = 0;
      await tester.pumpWidget(
        harness(
          HoppinTheme.driverDark(),
          SlideToConfirm(
            label: 'Slide to start',
            onConfirmed: () => confirms++,
          ),
        ),
      );
      final rest = tester.getCenter(thumb);

      // ~45% of usable travel — must spring home.
      await tester.drag(thumb, const Offset(140, 0));
      expect(confirms, 0);

      // Bounded pumps through the ~250ms spring-back.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 300));
      final after = tester.getCenter(thumb);
      expect((after - rest).distance, lessThan(1.0));
      expect(confirms, 0);
    });

    testWidgets('past threshold confirms exactly once', (tester) async {
      var confirms = 0;
      await tester.pumpWidget(
        harness(
          HoppinTheme.driverDark(),
          SlideToConfirm(
            label: 'Slide to start',
            onConfirmed: () => confirms++,
          ),
        ),
      );

      await tester.drag(thumb, const Offset(280, 0));
      expect(confirms, 1);

      // Snap-to-end settles; still exactly one confirm.
      await tester.pump(const Duration(milliseconds: 200));
      expect(confirms, 1);

      // Further drags on the finished slider do nothing.
      await tester.drag(thumb, const Offset(-200, 0), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.drag(thumb, const Offset(200, 0), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(confirms, 1);
    });

    testWidgets('disabled is inert — no movement, no confirm', (tester) async {
      var confirms = 0;
      await tester.pumpWidget(
        harness(
          HoppinTheme.driverDark(),
          SlideToConfirm(
            label: 'Slide to start',
            enabled: false,
            onConfirmed: () => confirms++,
          ),
        ),
      );
      final rest = tester.getCenter(thumb);

      await tester.drag(thumb, const Offset(140, 0), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(confirms, 0);
      expect(tester.getCenter(thumb), rest);
    });

    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('label present, no Opacity widget in subtree ($name)', (
        tester,
      ) async {
        await tester.pumpWidget(
          harness(
            theme,
            SlideToConfirm(label: 'Slide to complete', onConfirmed: () {}),
          ),
        );
        expect(find.text('Slide to complete'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SlideToConfirm),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
      });
    }
  });
}
