// LocationField — Figma spec: one white card. From row (navy bullet ring) +
// To row (red bullet ring) joined by a dashed hairline; each row = label
// over value + trailing edit affordance. Both rider themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '_pump.dart';

void main() {
  for (final MapEntry(key: name, value: theme) in riderThemes.entries) {
    final colors = colorsOf(theme);

    testWidgets('renders From + To rows with their values ($name)',
        (tester) async {
      await pumpComponent(
        tester,
        theme,
        const LocationField(
          fromLabel: 'From',
          fromValue: 'Wolverhampton Rail Station',
          toLabel: 'To',
          toValue: 'New Cross Hospital',
        ),
      );
      expect(find.text('From'), findsOneWidget);
      expect(find.text('Wolverhampton Rail Station'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
      expect(find.text('New Cross Hospital'), findsOneWidget);
    });

    testWidgets('From bullet is navy(accent), To bullet is red(error) ($name)',
        (tester) async {
      await pumpComponent(
        tester,
        theme,
        const LocationField(
          fromLabel: 'From',
          fromValue: 'A',
          toLabel: 'To',
          toValue: 'B',
        ),
      );
      final ringColors = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(LocationField),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle)
          .map((d) => d.border?.top.color)
          .toList();
      expect(ringColors, contains(colors.accent),
          reason: 'From ring is navy accent');
      expect(ringColors, contains(colors.error),
          reason: 'To ring is red error');
    });

    testWidgets('tapping a row fires its edit callback ($name)',
        (tester) async {
      var fromTaps = 0;
      var toTaps = 0;
      await pumpComponent(
        tester,
        theme,
        LocationField(
          fromLabel: 'From',
          fromValue: 'A',
          toLabel: 'To',
          toValue: 'B',
          onEditFrom: () => fromTaps++,
          onEditTo: () => toTaps++,
        ),
      );
      await tester.tap(find.text('A'));
      await tester.tap(find.text('B'));
      expect(fromTaps, 1);
      expect(toTaps, 1);
    });
  }
}
