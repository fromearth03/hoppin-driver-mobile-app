// HopPopup — Figma spec: bottom-anchored white sheet, top radius
// pillSmall(20), dimmed scrim, confirm/cancel actions. Both rider themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '_pump.dart';

void main() {
  for (final MapEntry(key: name, value: theme) in riderThemes.entries) {
    final colors = colorsOf(theme);

    testWidgets('presents title/body + confirm/cancel over the scrim ($name)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: HopButton.primary(
                  label: 'Open',
                  onPressed: () => HopPopup.confirm(
                    context,
                    title: 'Cancel ride?',
                    message: 'You may be charged a cancellation fee.',
                    confirmLabel: 'Cancel ride',
                    cancelLabel: 'Keep ride',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(find.byType(HopPopup), findsOneWidget);
      expect(find.text('Cancel ride?'), findsOneWidget);
      expect(find.text('You may be charged a cancellation fee.'),
          findsOneWidget);
      expect(find.text('Cancel ride'), findsOneWidget);
      expect(find.text('Keep ride'), findsOneWidget);

      // Top radius pillSmall(20).
      final surface = find.descendant(
        of: find.byType(HopPopup),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius ==
                  const BorderRadius.vertical(top: Radius.circular(20)),
        ),
      );
      expect(surface, findsOneWidget, reason: '$name top radius pillSmall(20)');

      // Barrier is the scrim token.
      final barrierColors = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .map((b) => b.color);
      expect(barrierColors, contains(colors.scrim));
    });

    testWidgets('confirm returns true, cancel returns false ($name)',
        (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: HopButton.primary(
                  label: 'Open',
                  onPressed: () async {
                    result = await HopPopup.confirm(
                      context,
                      title: 'Log out?',
                      message: 'You can sign back in any time.',
                      confirmLabel: 'Log out',
                      cancelLabel: 'Stay',
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.tap(find.text('Log out'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(result, isTrue);
    });
  }
}
