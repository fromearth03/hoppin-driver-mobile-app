// Acceptance tests for the wave-1 brand components. Every widget pumps under
// all four HoppinTheme builders — components must resolve every colour
// through context.hoppin, so the tone/role assertions read expected values
// straight off each theme's HoppinColors extension.
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

void main() {
  group('HopButton', () {
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('onPressed fires on tap ($name)', (tester) async {
        var taps = 0;
        await pumpUnder(
          tester,
          theme,
          HopButton.primary(label: 'Confirm ride', onPressed: () => taps++),
        );
        await tester.tap(find.byType(HopButton));
        expect(taps, 1);
      });

      testWidgets('busy shows a spinner and swallows taps ($name)', (
        tester,
      ) async {
        var taps = 0;
        await pumpUnder(
          tester,
          theme,
          HopButton.primary(
            label: 'Confirm ride',
            busy: true,
            onPressed: () => taps++,
          ),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Confirm ride'), findsNothing);
        await tester.tap(find.byType(HopButton), warnIfMissed: false);
        expect(taps, 0);
      });

      testWidgets('primary is at least 52 tall and fills accent ($name)', (
        tester,
      ) async {
        await pumpUnder(
          tester,
          theme,
          HopButton.primary(label: 'Confirm ride', onPressed: () {}),
        );
        expect(
          tester.getSize(find.byType(HopButton)).height,
          greaterThanOrEqualTo(52),
        );
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(HopButton),
            matching: find.byType(Material),
          ),
        );
        expect(material.color, theme.extension<HoppinColors>()!.accent);
        expect(material.elevation, 0);
      });

      testWidgets('ghost paints no filled background ($name)', (tester) async {
        await pumpUnder(
          tester,
          theme,
          HopButton.ghost(label: 'Skip', onPressed: () {}),
        );
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(HopButton),
            matching: find.byType(Material),
          ),
        );
        expect(material.color, Colors.transparent);
        expect(material.elevation, 0);
      });
    }
  });

  group('HopCard', () {
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('radius 10, white surface, no rest border, flat ($name)', (
        tester,
      ) async {
        await pumpUnder(tester, theme, const HopCard(child: Text('Fare')));
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(HopCard),
                matching: find.byType(Material),
              )
              .first,
        );
        final colors = theme.extension<HoppinColors>()!;
        final shape = material.shape! as RoundedRectangleBorder;
        expect(shape.borderRadius, BorderRadius.circular(10));

        // LIGHT: the Figma card carries a soft shadow, not a hairline, at rest.
        // DARK: it carries a hairline, because the shadow does not exist there —
        // 8% black over a #0F1220 canvas paints nothing, and the cards had no
        // separation from the page at all. Dark elevates with a LINE.
        if (colors.cardBorder.a == 0) {
          expect(shape.side.style, BorderStyle.none);
        } else {
          expect(shape.side.color, colors.cardBorder);
        }
        expect(material.color, colors.card);
        expect(material.elevation, 0);
      });

      testWidgets('onTap fires when provided ($name)', (tester) async {
        var taps = 0;
        await pumpUnder(
          tester,
          theme,
          HopCard(onTap: () => taps++, child: const Text('Tap')),
        );
        await tester.tap(find.byType(HopCard));
        expect(taps, 1);
      });
    }
  });

  group('StatusPill', () {
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('tones resolve to matching HoppinColors roles ($name)', (
        tester,
      ) async {
        final colors = theme.extension<HoppinColors>()!;
        final cases = <PillTone, (Color, Color)>{
          PillTone.neutral: (colors.textMid, colors.card),
          PillTone.accent: (colors.accent, colors.accentSubtle),
          PillTone.success: (colors.success, colors.successSubtle),
          PillTone.warn: (colors.warn, colors.warnSubtle),
          PillTone.error: (colors.error, colors.errorSubtle),
        };
        for (final MapEntry(key: tone, value: (fg, bg)) in cases.entries) {
          await pumpUnder(
            tester,
            theme,
            StatusPill(tone: tone, label: 'On time'),
          );
          final text = tester.widget<Text>(find.text('On time'));
          expect(text.style!.color, fg, reason: '$name/$tone foreground');
          final container = tester.widget<Container>(
            find
                .descendant(
                  of: find.byType(StatusPill),
                  matching: find.byType(Container),
                )
                .first,
          );
          final deco = container.decoration! as ShapeDecoration;
          expect(deco.color, bg, reason: '$name/$tone background');
          if (tone == PillTone.neutral) {
            final stadium = deco.shape as StadiumBorder;
            expect(
              stadium.side.color,
              colors.hairline,
              reason: '$name neutral pill carries the hairline border',
            );
          }
        }
      });

      testWidgets('renders a leading dot when dot: true ($name)', (
        tester,
      ) async {
        final colors = theme.extension<HoppinColors>()!;
        await pumpUnder(
          tester,
          theme,
          const StatusPill(tone: PillTone.success, label: 'Live', dot: true),
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
      });

      testWidgets('numeric pill resolves to the packaged Poppins family '
          '($name)', (
        tester,
      ) async {
        await pumpUnder(
          tester,
          theme,
          const StatusPill(
            tone: PillTone.accent,
            label: '4 min',
            numeric: true,
          ),
        );
        // R1 swapped GeistMono → Poppins; the numeric pill keeps tabular
        // figures on the Figma family, never the rejected mono.
        final text = tester.widget<Text>(find.text('4 min'));
        expect(text.style!.fontFamily, 'packages/hoppin_ui/Poppins');
      });
    }
  });

  group('HopSheet', () {
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('show presents a modal sheet over the scrim ($name)', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: HopButton.ghost(
                    label: 'Open',
                    expand: false,
                    onPressed: () => HopSheet.show<void>(
                      context,
                      builder: (_) => const Text('Sheet body'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        // Bounded pumps — the sheet entrance animates; never settle-pump.
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }

        final colors = theme.extension<HoppinColors>()!;
        expect(find.byType(HopSheet), findsOneWidget);
        expect(find.text('Sheet body'), findsOneWidget);

        // Sheet surface: top radius 16, drawn by the HopSheet container.
        final surface = find.descendant(
          of: find.byType(HopSheet),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).borderRadius ==
                    const BorderRadius.vertical(top: Radius.circular(16)),
          ),
        );
        expect(surface, findsOneWidget, reason: '$name sheet top radius 16');

        // Drag handle: 36x4, centered at the top.
        final handle = find.descendant(
          of: find.byType(HopSheet),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints ==
                    const BoxConstraints.tightFor(width: 36, height: 4),
          ),
        );
        expect(handle, findsOneWidget, reason: '$name drag handle rendered');

        // Barrier: the modal scrim is the HoppinColors scrim token.
        final barrierColors = tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .map((b) => b.color);
        expect(
          barrierColors,
          contains(colors.scrim),
          reason: '$name barrier must be the scrim token',
        );
      });
    }
  });

  group('PlateChip', () {
    testWidgets('light themes render the yellow rear plate', (tester) async {
      for (final theme in [themes['riderLight']!, themes['driverLight']!]) {
        await pumpUnder(tester, theme, const PlateChip(reg: 'BK72 WNH'));
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(PlateChip),
                matching: find.byType(Container),
              )
              .first,
        );
        final deco = container.decoration! as BoxDecoration;
        expect(deco.color, const Color(0xFFF7D117));
        final text = tester.widget<Text>(find.text('BK72 WNH'));
        expect(text.style!.color, const Color(0xFF161513));
      }
    });

    testWidgets('dark themes render the white front plate', (tester) async {
      for (final theme in [themes['riderDark']!, themes['driverDark']!]) {
        await pumpUnder(tester, theme, const PlateChip(reg: 'BK72 WNH'));
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(PlateChip),
                matching: find.byType(Container),
              )
              .first,
        );
        final deco = container.decoration! as BoxDecoration;
        expect(deco.color, const Color(0xFFEFEEE9));
        final text = tester.widget<Text>(find.text('BK72 WNH'));
        expect(text.style!.color, const Color(0xFF161513));
      }
    });

    testWidgets('uppercases the registration', (tester) async {
      await pumpUnder(
        tester,
        themes['riderLight']!,
        const PlateChip(reg: 'bk72 wnh'),
      );
      expect(find.text('BK72 WNH'), findsOneWidget);
      expect(find.text('bk72 wnh'), findsNothing);
    });

    testWidgets('characters resolve to the packaged Poppins family', (
      tester,
    ) async {
      await pumpUnder(
        tester,
        themes['riderLight']!,
        const PlateChip(reg: 'BK72 WNH'),
      );
      // The plate motif keeps its w600 tabular characters on the Figma
      // Poppins family — GeistMono was the rejected design.
      final text = tester.widget<Text>(find.text('BK72 WNH'));
      expect(text.style!.fontFamily, 'packages/hoppin_ui/Poppins');
      expect(text.style!.fontWeight, FontWeight.w600);
    });

    testWidgets('size lg renders larger than md', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themes['riderLight']!,
          home: const Scaffold(
            body: Column(
              children: [
                PlateChip(reg: 'BK72 WNH', key: Key('md')),
                PlateChip(reg: 'BK72 WNH', size: PlateSize.lg, key: Key('lg')),
              ],
            ),
          ),
        ),
      );
      final md = tester.getSize(find.byKey(const Key('md')));
      final lg = tester.getSize(find.byKey(const Key('lg')));
      expect(lg.width, greaterThan(md.width));
      expect(lg.height, greaterThan(md.height));
    });
  });

  group('HopBanner', () {
    /// True when any decorated surface inside the banner carries [color].
    bool hasFill(WidgetTester tester, Color color) {
      return tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(HopBanner),
              matching: find.byType(DecoratedBox),
            ),
          )
          .any((w) {
            final d = w.decoration;
            return d is BoxDecoration && d.color == color;
          });
    }

    Finder leadingBar(Color tone) => find.descendant(
          of: find.byType(HopBanner),
          matching: find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == tone,
          ),
        );

    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('error tone: error bar over errorSubtle surface ($name)', (
        tester,
      ) async {
        final colors = theme.extension<HoppinColors>()!;
        await pumpUnder(
          tester,
          theme,
          const HopBanner.error(message: 'Payment failed. Try again.'),
        );
        expect(find.text('Payment failed. Try again.'), findsOneWidget);
        expect(hasFill(tester, colors.errorSubtle), isTrue,
            reason: 'the surface is the errorSubtle tint');
        expect(leadingBar(colors.error), findsOneWidget,
            reason: 'the leading edge carries the tone colour');
        expect(
          tester.getSize(leadingBar(colors.error)).width,
          3,
          reason: 'the accent bar is the 3px hairline-family edge',
        );
        final message =
            tester.widget<Text>(find.text('Payment failed. Try again.'));
        expect(message.style!.color, colors.textHi);
      });

      testWidgets('notice tone maps to the lane accent ($name)', (
        tester,
      ) async {
        final colors = theme.extension<HoppinColors>()!;
        await pumpUnder(
          tester,
          theme,
          const HopBanner.notice(message: 'Driver running late'),
        );
        expect(hasFill(tester, colors.accentSubtle), isTrue);
        expect(leadingBar(colors.accent), findsOneWidget);
      });

      testWidgets('success tone maps to the success role ($name)', (
        tester,
      ) async {
        final colors = theme.extension<HoppinColors>()!;
        await pumpUnder(
          tester,
          theme,
          const HopBanner.success(message: 'Promo applied'),
        );
        expect(hasFill(tester, colors.successSubtle), isTrue);
        expect(leadingBar(colors.success), findsOneWidget);
      });
    }

    testWidgets('optional action renders and fires exactly once', (
      tester,
    ) async {
      var taps = 0;
      await pumpUnder(
        tester,
        themes['riderLight']!,
        HopBanner.error(
          message: 'Payment failed.',
          actionLabel: 'Retry',
          onAction: () => taps++,
        ),
      );
      await tester.tap(find.text('Retry'));
      expect(taps, 1);
    });

    testWidgets('no action renders message-only', (tester) async {
      await pumpUnder(
        tester,
        themes['riderLight']!,
        const HopBanner.notice(message: 'Heads up'),
      );
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('survives unbounded height (list body) without a wrapper', (
      tester,
    ) async {
      final colors = themes['riderLight']!.extension<HoppinColors>()!;
      await pumpUnder(
        tester,
        themes['riderLight']!,
        ListView(
          children: const [
            HopBanner.error(message: 'Payment failed. Try again.'),
          ],
        ),
      );
      expect(tester.takeException(), isNull,
          reason: 'the banner must own its height in unbounded contexts');
      // The tone bar still spans the banner's full (finite) height.
      final barHeight = tester.getSize(leadingBar(colors.error)).height;
      final bannerHeight =
          tester.getSize(find.byType(HopBanner)).height;
      expect(barHeight, bannerHeight);
      expect(barHeight, greaterThan(0));
    });
  });

  group('HopEmptyState', () {
    for (final MapEntry(key: name, value: theme) in themes.entries) {
      testWidgets('headline is Poppins 600, supporting is textMid ($name)', (
        tester,
      ) async {
        final colors = theme.extension<HoppinColors>()!;
        await pumpUnder(
          tester,
          theme,
          const HopEmptyState(
            headline: 'No trips yet',
            supporting: 'Your completed rides will appear here.',
          ),
        );
        // R1 swapped the whole scale to Poppins; the headline is the section
        // weight (w600) on the Figma family.
        final headline = tester.widget<Text>(find.text('No trips yet'));
        expect(headline.style!.fontFamily, 'packages/hoppin_ui/Poppins');
        expect(headline.style!.fontWeight, FontWeight.w600);
        expect(headline.style!.color, colors.textHi);
        expect(headline.textAlign, TextAlign.center);
        final supporting = tester.widget<Text>(
          find.text('Your completed rides will appear here.'),
        );
        expect(supporting.style!.color, colors.textMid);
        expect(supporting.textAlign, TextAlign.center);
      });
    }

    testWidgets('optional action is a HopButton firing exactly once', (
      tester,
    ) async {
      var taps = 0;
      await pumpUnder(
        tester,
        themes['riderLight']!,
        HopEmptyState(
          headline: 'No saved places',
          supporting: 'Save home and work for one-tap booking.',
          actionLabel: 'Add a place',
          onAction: () => taps++,
        ),
      );
      expect(find.byType(HopButton), findsOneWidget);
      await tester.tap(find.text('Add a place'));
      expect(taps, 1);
    });

    testWidgets('no action means no button', (tester) async {
      await pumpUnder(
        tester,
        themes['riderLight']!,
        const HopEmptyState(headline: 'Nothing here', supporting: 'Yet.'),
      );
      expect(find.byType(HopButton), findsNothing);
    });

    testWidgets('compact renders tighter than the full-height state', (
      tester,
    ) async {
      await pumpUnder(
        tester,
        themes['riderLight']!,
        const HopEmptyState(headline: 'Nothing here', supporting: 'Yet.'),
      );
      final full = tester.getSize(find.byType(HopEmptyState)).height;
      await pumpUnder(
        tester,
        themes['riderLight']!,
        const HopEmptyState(
          headline: 'Nothing here',
          supporting: 'Yet.',
          compact: true,
        ),
      );
      final compact = tester.getSize(find.byType(HopEmptyState)).height;
      expect(compact, lessThan(full));
    });
  });
}
