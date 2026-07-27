// FareEstimateCard — Figma spec: white card. label/amount rows; surge row
// with the multiplier in RED; hairline divider; centred total in the
// fareTotal (Poppins SemiBold ~22 navy) style. Both rider themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '_pump.dart';

void main() {
  for (final MapEntry(key: name, value: theme) in riderThemes.entries) {
    final colors = colorsOf(theme);

    testWidgets('renders line rows + total ($name)', (tester) async {
      await pumpComponent(
        tester,
        theme,
        const FareEstimateCard(
          lines: [
            FareLine(label: 'Base fare', amount: '£4.20'),
            FareLine(label: 'Distance', amount: '£3.20'),
          ],
          totalAmount: '£8.36',
        ),
      );
      expect(find.text('Base fare'), findsOneWidget);
      expect(find.text('£4.20'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('£8.36'), findsOneWidget);
    });

    testWidgets('total uses the fareTotal style in navy(textHi) ($name)',
        (tester) async {
      await pumpComponent(
        tester,
        theme,
        const FareEstimateCard(
          lines: [FareLine(label: 'Base fare', amount: '£4.20')],
          totalAmount: '£8.36',
        ),
      );
      final total = tester.widget<Text>(find.text('£8.36'));
      expect(total.style!.fontFamily, 'packages/hoppin_ui/Poppins');
      expect(total.style!.fontWeight, FontWeight.w600);
      expect(total.style!.color, colors.textHi);
    });

    testWidgets('surge multiplier renders in RED(error) ($name)',
        (tester) async {
      await pumpComponent(
        tester,
        theme,
        const FareEstimateCard(
          lines: [
            FareLine(label: 'Base fare', amount: '£4.20'),
            FareLine(label: 'Surge', amount: '£2.10', surgeMultiplier: '1.5x'),
          ],
          totalAmount: '£8.36',
        ),
      );
      final multiplier = tester.widget<Text>(find.text('1.5x'));
      expect(multiplier.style!.color, colors.error);
    });
  }
}
