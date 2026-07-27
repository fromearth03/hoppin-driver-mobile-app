import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/src/tokens/primitives.dart';
import 'package:hoppin_ui/src/tokens/semantic.dart';

void main() {
  test('rider light resolves Figma canvas + ink accent + selected tint', () {
    final c = hoppinSemanticColors(HoppinApp.rider, Brightness.light);
    expect(c.canvas, HoppinPrimitives.canvasLight);
    expect(c.accent, HoppinPrimitives.ink);
    expect(c.selectedTint, HoppinPrimitives.selectedTintLight);
    expect(c.selectedBorder, HoppinPrimitives.ink);
    expect(c.success, HoppinPrimitives.successGreen);
  });

  test('rider dark uses derived ramp, never pure white text', () {
    final c = hoppinSemanticColors(HoppinApp.rider, Brightness.dark);
    expect(c.canvas, HoppinPrimitives.canvasDark);
    expect(c.textHi, isNot(const Color(0xFFFFFFFF)));
  });

  // 🔴 DARK ELEVATES WITH A LINE, NOT A SHADOW.
  //
  // The resting card shadow is 8% black. Over the LIGHT canvas (#F6FAFC) that
  // reads as a soft lift. Over the DARK canvas (#0F1220) it is, to the eye,
  // nothing at all — you cannot darken something that is already almost black.
  // So in dark the cards had NO separation from the page whatsoever: a 6%
  // luminance step (#191D2E on #0F1220) and an invisible cast. The surface
  // hierarchy that reads beautifully in light was simply flat.
  //
  // That is a rule about the medium, not a preference — and this is where it is
  // pinned, so a future dark-ramp re-tune cannot quietly un-fix it.
  test('dark cards carry a border; light cards carry only their shadow', () {
    final light = hoppinSemanticColors(HoppinApp.rider, Brightness.light);
    final dark = hoppinSemanticColors(HoppinApp.rider, Brightness.dark);

    expect(
      light.cardBorder.a,
      0,
      reason: 'light separates by shadow. A line on top of a cast only muddies '
          'it — that is why the Figma card has no border.',
    );
    expect(
      dark.cardBorder.a,
      greaterThan(0),
      reason: 'dark separates by LINE. Its shadow is invisible, so without this '
          'the cards sit on the page with nothing to distinguish them from it.',
    );
  });

  // ── GLASS ───────────────────────────────────────────────────────────────
  //
  // The frosted chrome is the only place in the palette where a colour is
  // allowed to be translucent, and it is translucent ON PURPOSE: it is painted
  // over a live BackdropFilter, and the alpha is what lets the page blur
  // through. That freedom has a cost, and this is where it is paid — a
  // translucent bar takes on whatever is passing underneath it, so its text
  // contrast is not a fixed number you can eyeball once. It is a WORST CASE, and
  // the worst case is what has to hold.
  group('glass', () {
    /// Relative luminance (WCAG 2.x).
    double luminance(Color c) => c.computeLuminance();

    /// WCAG contrast ratio between two OPAQUE colours.
    double contrast(Color fg, Color bg) {
      final a = luminance(fg);
      final b = luminance(bg);
      final hi = a > b ? a : b;
      final lo = a > b ? b : a;
      return (hi + 0.05) / (lo + 0.05);
    }

    test('it is the ONLY translucent role — everything else stays opaque', () {
      for (final brightness in Brightness.values) {
        final c = hoppinSemanticColors(HoppinApp.rider, brightness);
        // Every other surface precomputes its blend against canvas, so a
        // component can paint it without a layer behind it and get the right
        // pixel. Glass (and the scrim, which is a barrier by definition)
        // cannot.
        for (final opaque in [
          c.canvas,
          c.card,
          c.raised,
          c.accent,
          c.accentSubtle,
          c.selectedTint,
          c.textHi,
        ]) {
          expect(opaque.a, 1.0);
        }
        expect(
          c.glass.a,
          lessThan(1.0),
          reason: 'an opaque "glass" fill hides the blur it is sitting on — '
              'the BackdropFilter becomes pure cost with zero visible effect, '
              'which is the classic way this style ships broken',
        );
        expect(c.glassEdge.a, lessThan(1.0));
      }
    });

    test('dark glass is a LIFTED slate, never a hole in the page', () {
      final dark = hoppinSemanticColors(HoppinApp.rider, Brightness.dark);
      // Composite the bar over the darkest thing it can float above: its own
      // canvas. If the result is not LIGHTER than that canvas, the bar is not a
      // pane of material sitting above the surface — it is an absence of one.
      final overCanvas = Color.alphaBlend(dark.glass, dark.canvas);
      expect(
        luminance(overCanvas),
        greaterThan(luminance(dark.canvas)),
        reason: 'dark glass must LIFT off the canvas. Near-black glass over a '
            'near-black page reads as a void, not a bar.',
      );
    });

    test('light glass stays translucent enough to actually frost', () {
      final light = hoppinSemanticColors(HoppinApp.rider, Brightness.light);
      expect(
        light.glass.a,
        inInclusiveRange(0.5, 0.85),
        reason: 'above ~0.85 nothing shows through and it is just a white bar; '
            'below ~0.5 the ink starts to swim over whatever passes beneath',
      );
    });

    // 🔴 THE CONTRAST FLOOR. Text on glass is the usual failure of this style:
    // it looks immaculate over the empty top of a list and becomes unreadable
    // the moment a dark card, a photo or a map tile scrolls under it. So we do
    // not test contrast against the resting canvas — we test it against the
    // WORST backdrop the bar can plausibly be dragged over, in each theme.
    test('chrome text survives the WORST backdrop it can float over', () {
      // Light: the darkest thing on a light page is the navy ink itself (an
      // accent card, a dark map tile, a photo).
      final light = hoppinSemanticColors(HoppinApp.rider, Brightness.light);
      final worstLight = Color.alphaBlend(light.glass, light.accent);
      expect(
        contrast(light.textHi, worstLight),
        greaterThanOrEqualTo(4.5),
        reason: 'navy-on-glass fails WCAG AA when a dark surface passes under '
            'the bar. Either the fill needs more white or the text needs more '
            'weight — do NOT ship it and hope nothing dark scrolls past.',
      );

      // Dark: the brightest thing on a dark page is a white-ish surface (a map
      // in light tiles, an image, a plate chip).
      final dark = hoppinSemanticColors(HoppinApp.rider, Brightness.dark);
      final worstDark = Color.alphaBlend(dark.glass, HoppinPrimitives.cardLight);
      expect(
        contrast(dark.textHi, worstDark),
        greaterThanOrEqualTo(4.5),
        reason: 'off-white text on dark glass fails AA when something BRIGHT '
            'passes under the bar',
      );

      // And the resting case, which must obviously be comfortable.
      expect(
        contrast(
          light.textHi,
          Color.alphaBlend(light.glass, light.canvas),
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(dark.textHi, Color.alphaBlend(dark.glass, dark.canvas)),
        greaterThanOrEqualTo(4.5),
      );
    });

    // 🔴 THE SHEET TIER, AND WHY IT IS A SECOND NUMBER.
    //
    // The chrome floor above is computed for TITLES AND ICONS. A modal sheet
    // does a different job: it carries mid-emphasis body copy at 14pt that
    // someone reads a paragraph of. Reusing the chrome's 72% fill there
    // measures 3.94:1 for dark secondary text over the worst backdrop a sheet
    // can float above — under AA, on prose. That is the whole reason
    // `glassSheet` exists, and this is the test that stops someone "tidying"
    // the two tokens back into one.
    //
    // A sheet floats over the SCRIM, so its worst backdrop is the scrim's worst
    // case, not the raw page: dark's danger is something BRIGHT underneath (a
    // light map tile, a photo); light's is the navy ink.
    test('sheet glass carries BODY COPY over the worst backdrop', () {
      for (final brightness in Brightness.values) {
        final c = hoppinSemanticColors(HoppinApp.rider, brightness);
        final dark = brightness == Brightness.dark;

        // The page at its worst, seen through the modal scrim.
        final page = dark ? HoppinPrimitives.cardLight : c.accent;
        final behindSheet = Color.alphaBlend(c.scrim, page);
        final surface = Color.alphaBlend(c.glassSheet, behindSheet);

        // textMid is the one that fails first — it is the emphasis level the
        // chrome tier never has to carry.
        final mid = Color.alphaBlend(c.textMid, surface);
        expect(
          contrast(mid, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness sheet: secondary copy falls under AA. The sheet '
              'fill is the knob — do NOT fix this by making the body text '
              'high-emphasis, which just deletes the type hierarchy.',
        );
        expect(
          contrast(c.textHi, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness sheet: primary copy falls under AA',
        );
      }
    });

    // The sheet tier is allowed to be denser. It is NOT allowed to be opaque —
    // at that point it is a card with a BackdropFilter behind it doing nothing
    // but costing a saveLayer, which is the failure the whole glass note warns
    // about.
    test('sheet glass is DENSER than chrome glass, and still frosts', () {
      for (final brightness in Brightness.values) {
        final c = hoppinSemanticColors(HoppinApp.rider, brightness);
        expect(
          c.glassSheet.a,
          greaterThan(c.glass.a),
          reason: 'a sheet reads body copy; it needs more fill than a nav bar. '
              'If these are equal, one of them is wrong.',
        );
        expect(
          c.glassSheet.a,
          lessThan(1.0),
          reason: 'an opaque sheet "glass" is a card with an expensive no-op '
              'behind it — the blur costs a saveLayer and shows nothing',
        );
        expect(
          c.glassSheet.a,
          lessThanOrEqualTo(0.9),
          reason: 'above ~90% there is no show-through left to see and the '
              'material stops being glass in anything but name',
        );
      }
    });
  });
}
