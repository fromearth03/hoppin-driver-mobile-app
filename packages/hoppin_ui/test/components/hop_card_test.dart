// HopCard — Figma spec: white fill, radius card(10), HoppinShadows.card,
// no border at rest. Both rider themes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

import '_pump.dart';

void main() {
  for (final MapEntry(key: name, value: theme) in riderThemes.entries) {
    final colors = colorsOf(theme);

    testWidgets('white surface, radius 10, no rest border, card shadow ($name)',
        (tester) async {
      await pumpComponent(tester, theme, const HopCard(child: Text('Fare')));

      // The surface Material carries the card colour + radius 10 + flat.
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(HopCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, colors.card);
      expect(material.elevation, 0);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(10));

      // The resting EDGE is theme-dependent, and the reason is physics, not
      // taste: a shadow separates a card from the page only if the page is
      // light enough to darken. The Figma card carries its elevation with an
      // 8%-black cast, and 8% black painted over a #0F1220 canvas is — to the
      // eye — nothing at all. In dark the cards were sitting on the page with
      // NO separation of any kind: a 6% luminance step and an invisible shadow.
      //
      // So: light keeps its shadow and takes no border (a line on top of a cast
      // only muddies it). Dark carries its elevation with a LINE.
      if (colors.cardBorder.a == 0) {
        expect(shape.side.style, BorderStyle.none,
            reason: 'light: shadow carries elevation, no hairline on top of it');
      } else {
        expect(shape.side.color, colors.cardBorder,
            reason: 'dark: the line IS the elevation — the shadow cannot be seen');
      }

      // A soft offset shadow is drawn (HoppinShadows.card).
      final shadowed = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(HopCard),
          matching: find.byType(Container),
        ),
      );
      final anyShadow = shadowed.any((c) {
        final d = c.decoration;
        return d is BoxDecoration && (d.boxShadow?.isNotEmpty ?? false);
      });
      expect(anyShadow, isTrue, reason: '$name card carries a soft shadow');
    });

    testWidgets('onTap fires when provided ($name)', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        theme,
        HopCard(onTap: () => taps++, child: const Text('Tap')),
      );
      await tester.tap(find.byType(HopCard));
      expect(taps, 1);
    });
  }
}
