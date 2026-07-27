// Acceptance tests for the hoppin_ui token layer: semantic colour resolution,
// ThemeExtension copyWith/lerp mechanics, motion token values, spacing/radii
// statics, and the tabular-numeral typography contract.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';
import 'package:hoppin_ui/src/tokens/semantic.dart';

void main() {
  final riderLight = hoppinSemanticColors(HoppinApp.rider, Brightness.light);
  final riderDark = hoppinSemanticColors(HoppinApp.rider, Brightness.dark);
  final driverDark = hoppinSemanticColors(HoppinApp.driver, Brightness.dark);

  group('HoppinColors.lerp', () {
    test('t=0.0 returns the start scheme', () {
      final at0 = riderLight.lerp(riderDark, 0.0);
      expect(at0.accent, riderLight.accent);
      expect(at0.canvas, riderLight.canvas);
      expect(at0.textHi, riderLight.textHi);
      expect(at0.plateBg, riderLight.plateBg);
    });

    test('t=1.0 returns the end scheme', () {
      final at1 = riderLight.lerp(riderDark, 1.0);
      expect(at1.accent, riderDark.accent);
      expect(at1.canvas, riderDark.canvas);
      expect(at1.textHi, riderDark.textHi);
      expect(at1.plateBg, riderDark.plateBg);
    });

    test(
      't=0.5 actually interpolates (midpoint canvas is neither endpoint)',
      () {
        final mid = riderLight.lerp(riderDark, 0.5);
        expect(mid.canvas, isNot(riderLight.canvas));
        expect(mid.canvas, isNot(riderDark.canvas));
      },
    );
  });

  group('copyWith', () {
    test('HoppinColors: changing one field preserves all others', () {
      const replacement = Color(0xFF123456);
      final tweaked = riderLight.copyWith(accent: replacement);
      expect(tweaked.accent, replacement);
      expect(tweaked.onAccent, riderLight.onAccent);
      expect(tweaked.canvas, riderLight.canvas);
      expect(tweaked.card, riderLight.card);
      expect(tweaked.raised, riderLight.raised);
      expect(tweaked.hairline, riderLight.hairline);
      expect(tweaked.textHi, riderLight.textHi);
      expect(tweaked.textMid, riderLight.textMid);
      expect(tweaked.success, riderLight.success);
      expect(tweaked.warn, riderLight.warn);
      expect(tweaked.error, riderLight.error);
      expect(tweaked.plateBg, riderLight.plateBg);
      expect(tweaked.plateText, riderLight.plateText);
      expect(tweaked.scrim, riderLight.scrim);
    });

    test('HoppinMotion: changing one field preserves all others', () {
      const replacement = Duration(milliseconds: 1);
      final tweaked = HoppinMotion.standard.copyWith(fade: replacement);
      expect(tweaked.fade, replacement);
      expect(tweaked.quick, HoppinMotion.standard.quick);
      expect(tweaked.slow, HoppinMotion.standard.slow);
      expect(tweaked.countdownTotal, HoppinMotion.standard.countdownTotal);
      expect(tweaked.easeSignature, HoppinMotion.standard.easeSignature);
      expect(tweaked.easeOut, HoppinMotion.standard.easeOut);
    });
  });

  group('HoppinMotion values', () {
    const motion = HoppinMotion.standard;

    test('duration scale is 100/250/500ms', () {
      expect(motion.fade, const Duration(milliseconds: 100));
      expect(motion.quick, const Duration(milliseconds: 250));
      expect(motion.slow, const Duration(milliseconds: 500));
    });

    test('choreography durations match the motion spec', () {
      expect(motion.countdownTotal, const Duration(seconds: 15));
      expect(motion.tickerCountUp, const Duration(milliseconds: 900));
      expect(motion.morphOverlap, const Duration(milliseconds: 40));
      expect(
        motion.countdownBreatheWindow,
        const Duration(seconds: 3),
      );
      expect(motion.secondsTick, const Duration(seconds: 1));
    });

    test('easeSignature transforms 0 to 0 and 1 to 1', () {
      expect(motion.easeSignature.transform(0.0), 0.0);
      expect(motion.easeSignature.transform(1.0), 1.0);
    });
  });

  group('HoppinSpacing / HoppinRadii statics', () {
    test('gutter is 24, card radius 10, input radius 8', () {
      expect(HoppinSpacing.gutter, 24.0);
      expect(HoppinRadii.card, 10.0);
      expect(HoppinRadii.input, 8.0);
    });
  });

  group('HoppinType numeric styles', () {
    const numericStyles = <String, TextStyle>{
      'moneyHero': HoppinType.moneyHero,
      'moneyTitle': HoppinType.moneyTitle,
      'numeral': HoppinType.numeral,
      'numeralCaption': HoppinType.numeralCaption,
      'ledger': HoppinType.ledger,
      'plate': HoppinType.plate,
    };

    test('every numeric style carries tabular figures', () {
      for (final MapEntry(key: name, value: style) in numericStyles.entries) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: '$name must set FontFeature.tabularFigures()',
        );
      }
    });

    test('ledger also carries slashed zero', () {
      expect(
        HoppinType.ledger.fontFeatures,
        contains(const FontFeature.slashedZero()),
      );
    });

    test('all numeric styles resolve to the packaged Poppins family', () {
      for (final MapEntry(key: name, value: style) in numericStyles.entries) {
        expect(
          style.fontFamily,
          'packages/hoppin_ui/Poppins',
          reason: '$name must use the packaged Poppins family (the Figma '
              'money font — GeistMono was the rejected design)',
        );
      }
    });
  });

  group('Figma primitives resolve in both brightnesses', () {
    // The Figma "Passenger View" palette — navy ink, brand red, cool-white —
    // must be reachable through the semantic resolver in light AND dark.
    const ink = Color(0xFF181C3A);
    const red = Color(0xFFE33236);
    const canvasLight = Color(0xFFF6FAFC);

    test('light accent is navy ink #181C3A', () {
      expect(riderLight.accent, ink);
    });

    test('light canvas is cool-white #F6FAFC', () {
      expect(riderLight.canvas, canvasLight);
    });

    test('error role carries the Figma brand red #E33236 in light', () {
      expect(riderLight.error, red);
    });

    test('dark accent is the derived navy-on-dark ink (not raw navy)', () {
      // Raw navy vanishes on dark fills; the dark ramp lifts it.
      expect(riderDark.accent, const Color(0xFFC9CEE6));
      expect(riderDark.accent, isNot(ink));
    });
  });

  group('dark ramp matches the R1 derivation on disk', () {
    // Figma draws light only; the dark ramp is our first-class derivation.
    // Assert the exact values the primitives ship (not just "non-pure").
    test('rider dark canvas/card are the cool-dark ramp', () {
      expect(riderDark.canvas, const Color(0xFF0F1220));
      expect(riderDark.card, const Color(0xFF191D2E));
    });

    test('dark textHi is a warm off-white, never pure #FFF', () {
      expect(riderDark.textHi, const Color(0xFFECEEF5));
      expect(riderDark.textHi, isNot(const Color(0xFFFFFFFF)));
    });

    const pureBlack = Color(0xFF000000);
    const pureWhite = Color(0xFFFFFFFF);

    test('no pure #000/#FFF in dark canvas/card/raised/textHi/textMid', () {
      for (final scheme in [riderDark, driverDark]) {
        final fields = <String, Color>{
          'canvas': scheme.canvas,
          'card': scheme.card,
          'raised': scheme.raised,
          'textHi': scheme.textHi,
          'textMid': scheme.textMid,
        };
        for (final MapEntry(key: name, value: color) in fields.entries) {
          expect(color, isNot(pureBlack), reason: 'dark $name is pure black');
          expect(color, isNot(pureWhite), reason: 'dark $name is pure white');
        }
      }
    });
  });
}
