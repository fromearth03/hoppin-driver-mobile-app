import 'dart:ui';

/// Private primitives — import only within hoppin_ui; app code consumes
/// semantic tokens via `context.hoppin`.
///
/// Figma "Passenger View" palette: one navy ink and one brand red over
/// cool-white surfaces (light), with a derived cool-dark ramp (Figma draws
/// light only — dark is our first-class derivation).
abstract final class HoppinPrimitives {
  // Brand.
  static const ink = Color(0xFF181C3A); // primary navy
  static const red = Color(0xFFE33236); // secondary
  static const alertRed = Color(0xFFFF2E2E); // cancellation-policy heading

  // Light surfaces.
  static const canvasLight = Color(0xFFF6FAFC);
  static const cardLight = Color(0xFFFFFFFF);
  static const selectedTintLight = Color(0xFFF6F7FF);
  static const hairlineLight = Color(0x29000000); // ~16% black — card borders
  static const textHiLight = Color(0xFF000000);
  static const textMidLight = Color(0x99000000); // 60% black

  // Status (light).
  static const successGreen = Color(0xFF22C55E);
  static const successSubtleLight = Color(0xFFDDFEF3);
  static const alertSurfaceLight = Color(0xFFFFF3F3);

  // Derived dark ramp (design decision — re-tune at the fidelity check).
  static const canvasDark = Color(0xFF0F1220);
  static const cardDark = Color(0xFF191D2E);
  static const selectedTintDark = Color(0xFF232842);
  static const inkOnDark = Color(0xFFC9CEE6); // navy would vanish on dark fills
  static const textHiDark = Color(0xFFECEEF5); // never pure white
  static const textMidDark = Color(0xFF9AA0B4);
  static const hairlineDark = Color(0xFF2A2F42);
  static const successSubtleDark = Color(0xFF10321F);
  static const alertSurfaceDark = Color(0xFF2A1618);

  // UK number plates (functional motif retained): yellow rear plate (light),
  // white front plate (dark), dark characters.
  static const plateYellow = Color(0xFFF7D117);
  static const plateWhite = Color(0xFFEFEEE9);
  static const plateChars = Color(0xFF161513);

  // Scrim base — near-black; alpha applied at the semantic layer.
  static const scrimBase = Color(0xFF14130F);

  // ── Glass (floating chrome: the top pill + the bottom nav) ─────────────
  //
  // These are TRANSLUCENT ON PURPOSE. They are painted over a live
  // BackdropFilter, so the alpha is load-bearing: it is what lets the page
  // scroll through and read as frosted rather than as a tinted card. Nothing
  // else in the palette is allowed to be non-opaque — everything else
  // precomputes its blend against canvas.
  //
  // 🔴 LIGHT GLASS IS TINTED, NOT WHITE — AND THAT IS THE WHOLE FIX.
  //
  // This token shipped as pure white @72% and the owner's verdict was that the
  // glassmorphism "doesn't really show". He was right, and the reason is
  // arithmetic rather than taste: white @72% over the resting canvas (#F6FAFC)
  // composites to (252,254,254) against a canvas of (246,250,252). A SIX-COUNT
  // delta. The tint colour and the canvas colour were the same colour, so the
  // 28% show-through resolved to nothing and the app paid for a sigma-18 blur
  // that only appeared over dark content. An expensive no-op — the exact
  // failure the note at the top of this block warns about, shipped anyway.
  //
  // The fix is a fill that sits BELOW the canvas in luminance. That is the
  // counter-intuitive part and it is worth stating plainly, because the obvious
  // move (drop the alpha to "let more through") makes it WORSE: a lighter
  // composite is pulled toward the canvas it is trying to separate from, so
  // alpha and separation move TOGETHER here, not against each other. Measured,
  // over #F6FAFC:
  //
  //   pure white  @0.72 … (252,254,254)  delta  6  ← shipped. Invisible.
  //   #E8EDF5     @0.62 … (237,242,248)  delta  9
  //   #DCE4F0     @0.55 … (232,238,245)  delta 14
  //   #DCE4F0     @0.62 … (230,236,245)  delta 16  ← chosen
  //   #D6DFED     @0.62 … (226,233,243)  delta 20  ← reads grey/dirty
  //
  // #DCE4F0 is a cool blue-grey near-white — the navy ink (#181C3A) mixed into
  // white and pulled toward the canvas's own blue bias, so the pane reads as a
  // COOLER, DENSER piece of the same family rather than a grey card. Grey would
  // look soiled against a cool-white page; a saturated blue would look like a
  // default theme. This is the hue that reads as glass over a colourful map:
  // it has enough body to have something to bend, and the saturation matrix
  // (1.8) pulls the map's own colour up through it.
  //
  // 0.62 keeps it optically present without going opaque. The alpha is NOT the
  // knob the contrast floor cares about here (see the ladder in semantic_test —
  // black-on-glass over the navy worst case clears AA from 0.40 upward); the
  // binding constraint is the SHEET tier, which is why that token is a lighter
  // tint. See glassSheetLight.
  //
  // Dark: a LIFTED slate, never pure black — pure black glass over a dark
  // canvas is indistinguishable from a hole in the page. This is the selected
  // tint (#232842) at 72%, so the bar reads as a pane of frosted material
  // sitting ABOVE the surface, not as an absence of one. This one was always
  // right — dark got a real tint while light got white, and that asymmetry IS
  // what the owner was seeing. Left at 72%: its worst case (something BRIGHT
  // sliding under it) is what pins it.
  //
  // Both alphas are pinned by the CONTRAST FLOOR, not by taste (see the WCAG
  // worst-case test in tokens/semantic_test). Dark glass started at 66% and it
  // looked lovely — until you slide something BRIGHT under it (a light map
  // tile, a photo, the white plate chip), at which point the composite lifts to
  // 4.16:1 and the off-white text fails AA. 72% is where the worst case clears
  // 4.5:1 while the pane still shows a real 28% of what is passing behind it.
  static const glassLight = Color(0x9EDCE4F0); // cool blue-grey @ 62%
  static const glassDark = Color(0xB8232842); // lifted slate @ 72%

  // ── Glass, SHEET tier (frosted modal surfaces) ─────────────────────────
  //
  // 🔴 A SHEET IS NOT CHROME, AND THE DIFFERENCE IS MEASURED, NOT FELT.
  //
  // The bars above carry titles, icons and a badge — big glyphs, high-emphasis
  // colour, a second of attention each. A modal sheet carries PROSE: mid-emphasis
  // secondary copy, at 14pt, that someone actually reads. Same material, a much
  // harder legibility job, so the fill is NOT the same number.
  //
  // Measured, over the worst backdrop each theme can put under a sheet (the
  // sheet floats over the SCRIM, so the worst case is the scrim's own worst
  // case: a white card/map tile in dark, the navy ink in light):
  //
  //   dark, textMid @ 72% fill …… 3.94:1   ← FAILS AA. The chrome tier is not
  //                                          safe to reuse here; shipping it
  //                                          would put unreadable grey-on-grey
  //                                          body copy on a sheet and call it
  //                                          a style.
  //   dark, textMid @ 86% fill …… 4.70:1   ← clears, with 14% still showing
  //                                          through a sigma-18 blur across a
  //                                          surface far larger than a pill.
  //   light, textMid @ 86% fill … 5.24:1
  //
  // The alternative — keep 72% and paint an extra veil under the content — was
  // measured too and rejected: it needs ~30% additional black to reach the same
  // floor, which is more occlusion than simply making the fill honest, AND it
  // spends a blur it then hides. That is the "expensive no-op" this palette's
  // glass note already warns about, dressed up as a fix.
  //
  // So: 86%. Denser than the chrome tier ON PURPOSE, because the floor said so.
  // Do not "unify" these two numbers into one glass token — they are one
  // material at two duties, and the duty is what sets the alpha.
  //
  // 🔴 AND THE SHEET'S TINT IS LIGHTER THAN THE CHROME'S — for the same reason.
  //
  // When light chrome gained its cool tint (#DCE4F0, see glassLight), the
  // obvious tidy was to give the sheet the same hue. Measured, it is the one
  // change in this whole material that actually breaks a floor. At 86% fill the
  // sheet is nearly opaque, so its tint lands at nearly full strength, and
  // textMid (60% black) over the result:
  //
  //   #FFFFFF @0.86 … 5.21:1   ← shipped
  //   #E8EDF5 @0.86 … 4.93:1   ← chosen
  //   #DCE4F0 @0.86 … 4.77:1   ← the chrome tint. Only 0.27 of margin.
  //   #D6DFED @0.86 … 4.70:1
  //
  // The chrome tint would still technically pass, and that is exactly why this
  // note exists: 0.27 is not margin, it is luck, and the next person to nudge
  // textMid or the scrim spends it without knowing. The sheet's duty is PROSE —
  // it does not need to separate from the canvas the way a floating pill does,
  // because it arrives over a scrim that has already separated it. So it takes
  // the lighter tint (#E8EDF5): enough cool cast to belong to the same material
  // family, not enough to eat the body-copy floor.
  //
  // One material, two duties. The duty sets the alpha AND the tint.
  static const glassSheetLight = Color(0xDBE8EDF5); // cool near-white @ 86%
  static const glassSheetDark = Color(0xDB232842); // lifted slate @ 86%

  // The glass EDGE. Real frosted panes catch light on their rim: a bright
  // hairline on top of the blur is most of what sells the material. In light
  // that is near-white; in dark it is a low white lift (a dark border would
  // just be a groove).
  //
  // 🔴 DARK'S RIM WAS 14% AND IT WAS NOT THERE.
  //
  // Light's rim is 60%; dark's was 14% — a 4.3x asymmetry nobody had a reason
  // for. Measured against the dark pane (#1D2238), white @14% renders (61,65,84)
  // for a contrast of 1.56:1 — barely over the ~1.2:1 perceptual floor for a 1px
  // hairline, which means it survives a screenshot and vanishes on an actual
  // OLED at low brightness or under any ambient light. An optical material is
  // DEFINED by how its edges behave; this pane had no edge. Measured ladder over
  // the pane:
  //
  //   14% … 1.56:1  ← shipped. Not an edge.
  //   28% … 2.51:1
  //   32% … 2.88:1  ← chosen
  //   40% … 3.68:1  ← starts reading as a drawn outline, not a lit edge
  //   50% … 4.99:1  ← an effect
  //
  // 32% is deliberately BELOW the 40-50% that was suggested. Past ~36% the rim
  // stops looking like light catching a bevel and starts looking like a stroke
  // somebody drew around a rectangle — the tell of fake glass. 2.88:1 is a
  // crisp, definitively present hairline that still reads as LIGHT. Definition,
  // not weight.
  //
  // 🔴 AND LIGHT'S RIM WAS NOT AN EDGE EITHER — IT WAS THE WRONG COLOUR.
  //
  // Dark's 14% rim was the loud failure, so light's 60% looked like the healthy
  // one by comparison. It was not. A WHITE rim on a near-white pane is bounded
  // by arithmetic, and the ceiling is far under the floor. Over the (tinted)
  // light pane (230,236,245):
  //
  //   white  @60% … 1.11:1   ← shipped
  //   white  @85% … 1.16:1
  //   white @100% … 1.19:1   ← PURE WHITE. The most a white rim can ever be.
  //
  // No alpha rescues it: at full opacity it is still under the ~1.2:1 where a
  // hairline becomes perceptible. Light mode never had an edge, and no amount of
  // tuning the old token could have given it one — which is why this needed a
  // measurement rather than another nudge.
  //
  // So light's rim goes DARK, and that is the physics rather than a workaround.
  // A rim is the pane's edge catching light against WHAT IS BEHIND IT. In dark
  // the pane is lighter than its page, so its edge is a white lift. In light the
  // pane is now DARKER than the page (that is the whole tint fix — see
  // glassLight), so its edge is a navy deepening. Same optics, opposite sign,
  // because the figure/ground relationship is opposite. Navy and never black:
  // black on a cool-white page is a dirty groove, navy is the pane's own ink.
  //
  //   navy @30% … 1.89:1
  //   navy @40% … 2.39:1  ← chosen. A crisp, definite hairline.
  //   navy @50% … 3.13:1  ← reads as a drawn border
  static const glassEdgeLight = Color(0x66181C3A); // navy @ 40%
  static const glassEdgeDark = Color(0x52FFFFFF); // white @ 32%

  // 🔴 THE SPECULAR GETS ITS OWN TOKEN — it is not a factor of the rim.
  //
  // The top-arc highlight used to be derived as `glassEdge * 0.45`. That coupling
  // is why dark had no specular either: 14% x 0.45 = white @6.3%, which is below
  // the ~10% where a gradient reads as LIGHT rather than as banding noise. So a
  // conservative rim silently dragged the highlight under the visibility floor
  // with it, and the two faults compounded into a pane with neither.
  //
  // Deriving one optical property from another couples two things that answer to
  // different physics: a rim is light caught on an EDGE, a specular is light
  // reflected off a FACE. They are independent, so they are independent tokens.
  //
  // Dark at 20% (from 6.3%) reads as a lit top face; light stays at 27% (60% x
  // 0.45 — the old derived value, preserved deliberately: light's specular was
  // never the broken one, and re-tuning what already works is how you trade a
  // fixed bug for a new one).
  static const glassSpecularLight = Color(0x45FFFFFF); // white @ 27%
  static const glassSpecularDark = Color(0x33FFFFFF); // white @ 20%

  // 🔴 THE UNDER-RIM — the half of an edge that makes it 3D.
  //
  // A single bright rim all the way round is an OUTLINE. A real pane lit from
  // above catches light on its top edge and casts its own thickness into shadow
  // on the bottom one — that near/far asymmetry is most of what tells the eye
  // "slab" instead of "region with a filter on it". So the bottom arc gets a
  // dark counter-rim: navy in light (never black — black on a cool-white page is
  // a dirty groove), and a deeper near-black in dark.
  //
  // Kept low on purpose. This is the token most likely to look like an effect if
  // cranked: at 12% it is a shadow you feel and cannot point to, which is
  // exactly the job.
  static const glassUnderRimLight = Color(0x1F181C3A); // navy @ 12%
  static const glassUnderRimDark = Color(0x2E0A0C16); // near-black @ 18%

  // The shadow a FLOATING pill casts. Wider + softer + more diffuse than the
  // resting-card shadow: the pill sits further off the page than a card does,
  // and it has no top edge attached to anything. Dark needs a deeper cast —
  // a 10%-black shadow over a #0F1220 canvas is invisible.
  static const glassShadowLight = Color(0x1F000000); // ~12% black
  static const glassShadowDark = Color(0x59000000); // ~35% black

  // Blur radius fed to ImageFilter.blur on both axes. Chrome-wide constant:
  // the top pill and the bottom nav must frost identically or they read as
  // two different materials.
  //
  // Left at 18 deliberately, and the licence to raise it was real: web is
  // dropped (2026-07-16), so Skia's divergence-above-sigma-7 caveat is moot and
  // Impeller is happy at 20-24. It was not taken, because sigma was never the
  // fault. The light pane was invisible because its FILL was the canvas colour,
  // not because the blur was too weak — raising the sigma would have made an
  // invisible pane invisible more expensively. One full-width blur at this sigma
  // already costs ~6-9ms of raster on mid-tier Android against a 16.67ms budget,
  // and the driver app runs 8-hour shifts on exactly that hardware in a cradle.
  // Now that the tint does its job, re-measure by EYE before spending frame
  // budget on a number that was not the problem.
  static const double glassBlurSigma = 18.0;

  // 🔴 THE VIBRANCY BOOST — why frosted glass looks CHEAP without it.
  //
  // A Gaussian blur is a weighted AVERAGE of neighbouring pixels. Averaging
  // colour is averaging TOWARD GREY: a red car and a green verge blurred
  // together do not make a rich blend, they make mud. So a pure-blur backdrop
  // is not merely soft — it is DESATURATED, and desaturated is the exact
  // reading the eye files under "plastic" rather than "glass". This is the
  // single most common reason a hand-rolled frost looks like a screenshot of
  // frost.
  //
  // Every real implementation of this material compensates by pumping the
  // saturation back up AFTER the blur — Apple's UIBlurEffect does it inside the
  // private material, and the web's equivalent is the `saturate(180%)` that sits
  // next to `blur()` in every `backdrop-filter` recipe worth copying. Flutter's
  // BackdropFilter does NOT do this for you; you get the blur and nothing else,
  // which is why so much Flutter "glass" reads grey.
  //
  // 🔴 1.8, RAISED FROM 1.6 — AND THE REASON 1.6 WAS CHOSEN DOES NOT SURVIVE
  // MEASUREMENT.
  //
  // The previous note claimed 1.8 "sends the red (#E33236) toward fluorescing —
  // the bar picks up a pink cast the moment a fare chip scrolls under it". That
  // was asserted, not measured, and it is wrong on both halves. Coral through
  // this matrix:
  //
  //   base   (227,50,54)  hue 358.6°  sat 78.0%
  //   s=1.6  (255,27,34)  hue 358.2°  sat 89.4%   raw red channel 310 → CLIPPED
  //   s=1.8  (255,20,27)  hue 358.2°  sat 92.2%   raw red channel 338 → CLIPPED
  //
  // - There is no PINK CAST at any value in the range: hue moves 0.4° and then
  //   stops. Pink would need hue to climb toward 340°; it does not move.
  // - Coral's red channel does not "start" clipping at 1.8 — it is ALREADY hard
  //   clipped at the shipped 1.6 (raw 310 against a ceiling of 255). Whatever
  //   1.6 was protecting, it was not protecting that.
  //
  // What actually changes between 1.6 and 1.8 is coral's G and B being squeezed
  // (27,34) → (20,27), which DEEPENS the red rather than pinking it, and green
  // (#22C55E) drifting 10.4° — the largest real effect in the palette, and the
  // one that matters, because the map is full of greens and pulling the map's
  // colour up into the pane is the entire point of this token.
  //
  // So 1.8: the top of the range the contrast tests permit. A blur averages
  // toward grey, and this is the only knob that puts the chroma back — an
  // optical material shows you the colour of what is behind it. The neutrals are
  // untouched at 1.8 (verified exactly: every grey probe moves 0/255), which is
  // the property that keeps the glass on its contrast floor.
  //
  // Applied as a colour matrix COMPOSED OVER the blur (see HopGlass), never as
  // an approximation via extra tinted fills — a fill would change the alpha the
  // contrast floor is pinned to.
  static const double glassSaturation = 1.8;
}
