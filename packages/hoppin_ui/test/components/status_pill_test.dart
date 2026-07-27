// StatusPill — Figma spec: rounded-100 pill. success = successSubtle bg +
// success text + leading check. alert/neutral variants derive. Inline
// dot+label variant for the live-trip status. Both rider themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '_pump.dart';

void main() {
  for (final MapEntry(key: name, value: theme) in riderThemes.entries) {
    final colors = colorsOf(theme);

    testWidgets('success: successSubtle bg + success text + leading tick '
        '($name)', (tester) async {
      await pumpComponent(
        tester,
        theme,
        const StatusPill(tone: PillTone.success, label: 'Default'),
      );
      final text = tester.widget<Text>(find.text('Default'));
      expect(text.style!.color, colors.success);

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(StatusPill),
              matching: find.byType(Container),
            )
            .first,
      );
      final deco = container.decoration! as ShapeDecoration;
      expect(deco.color, colors.successSubtle);
      // Leading success glyph (the Figma ✓).
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('pill is fully rounded (stadium) ($name)', (tester) async {
      await pumpComponent(
        tester,
        theme,
        const StatusPill(tone: PillTone.neutral, label: 'Requested'),
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(StatusPill),
              matching: find.byType(Container),
            )
            .first,
      );
      final deco = container.decoration! as ShapeDecoration;
      expect(deco.shape, isA<StadiumBorder>());
    });

    testWidgets('error tone resolves to the error role ($name)',
        (tester) async {
      await pumpComponent(
        tester,
        theme,
        const StatusPill(tone: PillTone.error, label: 'Cancelled'),
      );
      final text = tester.widget<Text>(find.text('Cancelled'));
      expect(text.style!.color, colors.error);
    });

    testWidgets('inline dot variant: success dot + navy label, borderless '
        '($name)', (tester) async {
      await pumpComponent(
        tester,
        theme,
        const StatusPill(
          tone: PillTone.success,
          label: 'Driver En-route',
          dot: true,
        ),
      );
      final dot = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(StatusPill),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
      );
      expect((dot.decoration as BoxDecoration).color, colors.success);
      expect(find.text('Driver En-route'), findsOneWidget);
    });
  }
}
