// RideTypeCard — Figma spec: radius card(10). unselected = white + card
// shadow; selected = selectedTint fill + 1px navy(selectedBorder) border.
// name + capacity text present; tap reports selection. Both rider themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '_pump.dart';

void main() {
  Material cardMaterial(WidgetTester tester) => tester.widget<Material>(
        find
            .descendant(
              of: find.byType(RideTypeCard),
              matching: find.byType(Material),
            )
            .first,
      );

  for (final MapEntry(key: name, value: theme) in riderThemes.entries) {
    final colors = colorsOf(theme);

    testWidgets('unselected: white surface + card shadow, no navy border '
        '($name)', (tester) async {
      await pumpComponent(
        tester,
        theme,
        RideTypeCard(
          name: 'Standard',
          capacity: '4 seats • Upto 2 bags',
          icon: Icons.directions_car,
          onTap: () {},
        ),
      );
      final material = cardMaterial(tester);
      expect(material.color, colors.card);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(10));
      expect(shape.side.color, isNot(colors.selectedBorder));
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('4 seats • Upto 2 bags'), findsOneWidget);
    });

    testWidgets('selected: selectedTint fill + 1px navy border ($name)',
        (tester) async {
      await pumpComponent(
        tester,
        theme,
        RideTypeCard(
          name: 'MPV',
          capacity: '6 seats',
          icon: Icons.airport_shuttle,
          selected: true,
          onTap: () {},
        ),
      );
      final material = cardMaterial(tester);
      expect(material.color, colors.selectedTint);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, colors.selectedBorder);
      expect(shape.side.width, 1);
    });

    testWidgets('onTap fires when tapped ($name)', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        theme,
        RideTypeCard(
          name: 'Estate',
          capacity: '4 seats',
          icon: Icons.directions_car,
          onTap: () => taps++,
        ),
      );
      await tester.tap(find.byType(RideTypeCard));
      expect(taps, 1);
    });
  }
}
