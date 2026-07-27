// The vibrancy half of the frosted material.
//
// The blur is the half everybody implements; the saturation is the half that
// decides whether the result reads as GLASS or as grey plastic. A Gaussian blur
// averages colour toward grey, so a pure-blur pane is desaturated by
// construction — the matrix here is what puts the chroma back.
//
// It is a matrix of 20 floats, which is exactly the kind of thing that gets
// hand-typed slightly wrong and then looks "fine". These tests pin the two
// properties that make it correct rather than merely plausible: it must be the
// IDENTITY at s=1 (or every surface shifts the moment the token is touched), and
// it must PRESERVE LUMINANCE (or "more vivid" silently means "brighter", which
// would walk the glass off the contrast floor the whole palette is pinned to).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/src/tokens/primitives.dart';
import 'package:hoppin_ui/src/tokens/spacing.dart';

/// Applies a 4x5 colour matrix to a colour, the way the engine does.
Color applyMatrix(List<double> m, Color c) {
  final r = c.r * 255.0;
  final g = c.g * 255.0;
  final b = c.b * 255.0;
  final a = c.a * 255.0;

  double row(int i) =>
      m[i * 5] * r + m[i * 5 + 1] * g + m[i * 5 + 2] * b + m[i * 5 + 3] * a +
      m[i * 5 + 4];

  int clamp(double v) => v.round().clamp(0, 255);

  return Color.fromARGB(clamp(row(3)), clamp(row(0)), clamp(row(1)),
      clamp(row(2)));
}

void main() {
  group('glass saturation matrix', () {
    test('is a well-formed 4x5 colour matrix', () {
      expect(HoppinChrome.saturationMatrix().length, 20);
    });

    // If s=1 is not EXACTLY the identity, the matrix has a sign or a weight
    // wrong and every colour is being nudged even when nothing was asked for.
    test('is the identity at s = 1 — no saturation, no change', () {
      final m = HoppinChrome.saturationMatrix(1);
      for (final probe in const [
        Color(0xFFE33236), // brand red
        Color(0xFF181C3A), // navy ink
        Color(0xFFF6FAFC), // canvas
        Color(0xFF22C55E), // success green
        Color(0xFF808080), // mid grey
      ]) {
        final out = applyMatrix(m, probe);
        expect(out.r * 255, closeTo(probe.r * 255, 1), reason: '$probe red');
        expect(out.g * 255, closeTo(probe.g * 255, 1), reason: '$probe green');
        expect(out.b * 255, closeTo(probe.b * 255, 1), reason: '$probe blue');
      }
    });

    test('collapses to greyscale at s = 0', () {
      final m = HoppinChrome.saturationMatrix(0);
      final out = applyMatrix(m, const Color(0xFFE33236));
      expect(out.r * 255, closeTo(out.g * 255, 1));
      expect(out.g * 255, closeTo(out.b * 255, 1));
    });

    // 🔴 THE PROPERTY THAT PROTECTS THE CONTRAST FLOOR.
    //
    // Saturation must move colours AWAY FROM THEIR OWN LUMA, not up or down it.
    // A matrix that also lifts luminance would make the glass composite brighter
    // than the alpha the WCAG floor was computed against — the floor would still
    // pass its own test (it composites alpha, not chroma) while the real pixels
    // drifted out from under it. A NEUTRAL grey has no chroma to boost, so it is
    // the perfect canary: if grey moves at all, the matrix is not saturating, it
    // is exposure-shifting.
    test('leaves neutrals exactly alone — it saturates, it does not brighten',
        () {
      final m = HoppinChrome.saturationMatrix();
      for (final grey in const [
        Color(0xFF000000),
        Color(0xFF404040),
        Color(0xFF808080),
        Color(0xFFC0C0C0),
        Color(0xFFFFFFFF),
      ]) {
        final out = applyMatrix(m, grey);
        expect(
          out.r * 255,
          closeTo(grey.r * 255, 1),
          reason: 'a neutral gained chroma under the saturation matrix — the '
              'luma weights do not sum to 1, so the matrix is shifting '
              'exposure, and the glass will drift off the contrast floor',
        );
        expect(out.g * 255, closeTo(grey.g * 255, 1), reason: '$grey green');
        expect(out.b * 255, closeTo(grey.b * 255, 1), reason: '$grey blue');
      }
    });

    test('luma weights are Rec.601 and sum to 1 (the CSS saturate() basis)', () {
      // Row 0 of the s=0 matrix IS the luma vector — at zero saturation every
      // channel collapses onto it.
      final m = HoppinChrome.saturationMatrix(0);
      expect(m[0], closeTo(0.213, 1e-9));
      expect(m[1], closeTo(0.715, 1e-9));
      expect(m[2], closeTo(0.072, 1e-9));
      expect(m[0] + m[1] + m[2], closeTo(1.0, 1e-9));
    });

    test('actually boosts chroma at the shipped token', () {
      final m = HoppinChrome.saturationMatrix();
      const red = Color(0xFFE33236);
      final out = applyMatrix(m, red);
      double chroma(Color c) {
        final hi = [c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
        final lo = [c.r, c.g, c.b].reduce((a, b) => a < b ? a : b);
        return hi - lo;
      }

      expect(
        chroma(out),
        greaterThan(chroma(red)),
        reason: 'the whole point of the token is that the blurred backdrop comes '
            'back MORE colourful than the average the blur produced',
      );
    });

    // The number is a taste call, but it has a defensible range and shipping
    // outside it is a mistake, not a preference.
    test('the token sits in the credible vibrancy range', () {
      expect(
        HoppinPrimitives.glassSaturation,
        inInclusiveRange(1.4, 1.8),
        reason: 'below ~1.4 the boost is invisible and the glass stays muddy; '
            'above ~1.8 the brand red starts to fluoresce and the bar picks up '
            'a cast from whatever scrolls under it',
      );
    });

    test('the chrome view surfaces the same token the primitive defines', () {
      expect(HoppinChrome.saturation, HoppinPrimitives.glassSaturation);
    });
  });
}
