// The OPTICAL properties of the frosted material — the half that the contrast
// floor does not defend.
//
// 🔴 WHY THIS FILE EXISTS. The glass shipped with two faults that every existing
// test was blind to, because every existing test asked "is this LEGIBLE?" and
// none asked "is this VISIBLE?":
//
//   - Light glass was pure white @72% over a #F6FAFC canvas: a SIX-COUNT
//     composite delta. It passed the WCAG suite with 11.59:1 of margin while
//     being, to the eye, absent. A blur nobody could see, billed every frame.
//   - Dark's rim was white @14% (1.56:1 against the pane) and its specular was
//     derived from it at 6.3% — both under the threshold where a human notices
//     them. `semantic_test` only ever asserted `glassEdge.a < 1.0`.
//
// A material can be perfectly legible and completely invisible. The contrast
// tests measure the first; nothing measured the second, so the second is what
// rotted. These are the assertions that stop it rotting again.
//
// Every number here is a MEASURED floor with the ladder written next to it, per
// the convention in motion_guards_test:20-22 — not a taste range asserted and
// then inherited by people who cannot re-derive it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/src/tokens/primitives.dart';
import 'package:hoppin_ui/src/tokens/semantic.dart';

void main() {
  /// The largest per-channel distance between two opaque colours, in counts of
  /// 255. This is the "can you SEE it" metric the contrast ratio misses: two
  /// colours can sit at a comfortable contrast ratio and still be the same
  /// colour to within a rounding error.
  int channelDelta(Color a, Color b) {
    int d(double x, double y) => ((x - y).abs() * 255).round();
    return [d(a.r, b.r), d(a.g, b.g), d(a.b, b.b)]
        .reduce((x, y) => x > y ? x : y);
  }

  double contrast(Color fg, Color bg) {
    final a = fg.computeLuminance();
    final b = bg.computeLuminance();
    final hi = a > b ? a : b;
    final lo = a > b ? b : a;
    return (hi + 0.05) / (lo + 0.05);
  }

  group('glass optics — the material must be VISIBLE, not merely legible', () {
    // 🔴 THE REGRESSION THIS FILE WAS BORN FOR.
    //
    // The pane has to separate from the page it floats over, at REST, over the
    // resting canvas. Measured over #F6FAFC:
    //
    //   pure white @0.72 …  6/255  ← shipped for months. Invisible.
    //   #E8EDF5    @0.62 …  9/255
    //   #DCE4F0    @0.62 … 16/255  ← shipped now
    //
    // The floor is 12: below that the pane is within touching distance of the
    // canvas's own dithering and reads as a slightly-off rectangle rather than
    // a pane of anything. It is set BELOW the shipped 16 on purpose — this is a
    // floor, not a lock; retuning the hue is allowed, vanishing is not.
    test('light glass SEPARATES from the canvas it floats over', () {
      final light = hoppinSemanticColors(HoppinApp.rider, Brightness.light);
      final composite = Color.alphaBlend(light.glass, light.canvas);

      expect(
        channelDelta(composite, light.canvas),
        greaterThanOrEqualTo(12),
        reason: 'the light pane has dissolved into its own canvas. This is the '
            'exact bug this file exists for: white glass over a white page is '
            'an expensive no-op — a sigma-18 BackdropFilter, billed every '
            'frame, showing nothing. Do NOT fix it by lowering the alpha: '
            'alpha and separation move TOGETHER here, because a lighter '
            'composite is pulled toward the canvas it is trying to separate '
            'from. The knob is the TINT — the fill must sit below the canvas '
            'in luminance.',
      );
    });

    // The dark pane's fill was never the problem — it was always a real lifted
    // slate. This pins the asymmetry that WAS the problem: dark got a tint and
    // light got white, and that difference is what the owner was seeing.
    test('dark glass separates from ITS canvas too', () {
      final dark = hoppinSemanticColors(HoppinApp.rider, Brightness.dark);
      final composite = Color.alphaBlend(dark.glass, dark.canvas);
      expect(
        channelDelta(composite, dark.canvas),
        greaterThanOrEqualTo(12),
        reason: 'dark glass has stopped lifting off its canvas',
      );
    });

    // 🔴 THE RIM. An optical material is defined by how its EDGES behave, and
    // dark's edge was not there. Over the dark pane (#1D2238):
    //
    //   14% … 1.56:1  ← shipped. Survives a screenshot, vanishes on an OLED.
    //   28% … 2.51:1
    //   32% … 2.88:1  ← shipped now
    //   40% … 3.68:1  ← starts reading as a drawn outline
    //   50% … 4.99:1  ← an effect
    //
    // 2.0:1 is the floor: comfortably above the ~1.2:1 where a 1px hairline
    // stops being perceptible under ambient light, with room to re-tune.
    test('the rim is a visible EDGE in BOTH themes, not just light', () {
      // The pane each rim is drawn on: glass over the canvas it floats above.
      for (final brightness in Brightness.values) {
        final c = hoppinSemanticColors(HoppinApp.rider, brightness);
        final pane = Color.alphaBlend(c.glass, c.canvas);
        final rim = Color.alphaBlend(c.glassEdge, pane);

        expect(
          contrast(rim, pane),
          greaterThanOrEqualTo(2.0),
          reason: '$brightness: the rim has faded into the pane. Frosted glass '
              'is sold by the light on its edge; a rim under ~1.2:1 is not an '
              'edge, it is a rumour. (Dark shipped at 14% / 1.56:1 while light '
              'sat at 60% — a 4.3x asymmetry with no reason behind it.)',
        );
      }
    });

    // 🔴 THE COUPLING BUG, PINNED.
    //
    // The specular used to be `glassEdge * 0.45`. In dark that resolved to white
    // @6.3% — under the ~10% where a gradient reads as LIGHT rather than as
    // banding noise. One conservative rim value silently broke two independent
    // optical properties, and nothing caught it because nothing was looking.
    //
    // A rim is light caught on an EDGE. A specular is light off a FACE. They
    // answer to different physics, so they are different tokens, and this is the
    // test that stops someone "tidying" the specular back into a factor of the
    // rim.
    test('the specular is bright enough to read as LIGHT, in both themes', () {
      for (final brightness in Brightness.values) {
        final c = hoppinSemanticColors(HoppinApp.rider, brightness);
        expect(
          c.glassSpecular.a,
          greaterThanOrEqualTo(0.10),
          reason: '$brightness: the top-face highlight is under 10% alpha, '
              'which is where a gradient stops reading as a lit surface and '
              'starts reading as banding. If this broke because the RIM was '
              'lowered, that is the coupling this token was split out to '
              'prevent — do not re-derive one from the other.',
        );
        expect(
          c.glassSpecular.a,
          lessThan(1.0),
          reason: '$brightness: an opaque specular is a white bar, not a hint',
        );
      }
    });

    // The pane needs a NEAR face and a FAR one. A single bright rim all the way
    // round is an outline; the asymmetry is what reads as thickness.
    test('the pane has a dark counter-rim, so it has two faces', () {
      for (final brightness in Brightness.values) {
        final c = hoppinSemanticColors(HoppinApp.rider, brightness);
        final pane = Color.alphaBlend(c.glass, c.canvas);
        final under = Color.alphaBlend(c.glassUnderRim, pane);

        expect(
          under.computeLuminance(),
          lessThan(pane.computeLuminance()),
          reason: '$brightness: the under-rim is not DARKER than the pane, so '
              'it is not a shadow and the pane has no far face — it is a '
              'uniform outline again, which is a drawn rectangle.',
        );
        expect(
          c.glassUnderRim.a,
          lessThanOrEqualTo(0.25),
          reason: '$brightness: the under-rim is a shadow you feel and cannot '
              'point at. Above ~25% it stops being thickness and starts being '
              'a dark border, which is the tell of fake glass.',
        );
      }
    });

    // The saturation is what pulls the live map's colour up INTO the pane — the
    // blur averages toward grey, this is the only thing that puts the chroma
    // back. Pinned at the top of the credible range with the coral claim that
    // used to justify 1.6 measured and rebutted in the primitives note.
    test('the vibrancy sits at the top of the credible range', () {
      expect(HoppinPrimitives.glassSaturation, 1.8);
    });
  });
}
