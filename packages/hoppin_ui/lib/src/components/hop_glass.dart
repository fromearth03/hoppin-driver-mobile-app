import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/context_extension.dart';
import '../tokens/spacing.dart';

/// A pane of frosted glass — the one place the material is defined.
///
/// The top pill, the bottom nav and the modal sheet all build from this,
/// deliberately: two hand-rolled blurs drift apart and start reading as two
/// different materials.
///
/// 🔴 **The blur is the point, and it only works if something is BEHIND it.**
/// `BackdropFilter` filters what has already been painted into the layer under
/// it — so a [HopGlass] that sits in a `Column` above its content has nothing
/// to sample and degrades, silently, into a translucent tinted box. That is the
/// classic failure of this style and it looks fine in a screenshot, which is why
/// it ships. The chrome must be LAYERED over scrolling content (a `Stack`, or a
/// `Scaffold` with `extendBody`/`extendBodyBehindAppBar`), never stacked above
/// it. See `RiderShell`.
///
/// 🔴 **A blur alone is not the material — it is half of it.** Gaussian blur is
/// an average, and averaging colour walks it toward grey, so a pure-blur pane
/// comes out MUDDY: technically frosted, visibly cheap. Every convincing version
/// of this material pumps the chroma back up on the far side of the blur (Apple
/// does it inside UIBlurEffect; the web spells it `saturate(180%)` right next to
/// `blur()`). Flutter's [BackdropFilter] does not do it for you. So this
/// composes a saturation colour-matrix OVER the blur — see
/// [HoppinChrome.saturation]. Remove it and every glass surface in the app goes
/// grey at once, which is precisely why it lives here and not at a call site.
///
/// The fill ([HoppinColors.glass]), the rim ([HoppinColors.glassEdge]), the cast
/// ([HoppinShadows.glass]), the sigma ([HoppinChrome.blurSigma]) and the
/// vibrancy ([HoppinChrome.saturation]) are all tokens. No component is allowed
/// its own alpha.
/// Which DUTY a pane of glass is doing — which decides how dense its fill is.
///
/// 🔴 This is an enum and not a `Color` parameter on purpose. "Let the caller
/// pass a fill" is how a design system acquires nine slightly different glasses
/// and a contrast floor nobody can state. The tiers are the two duties the
/// material actually has; each one's alpha is a token pinned by a measured WCAG
/// worst case. A surface picks its DUTY. It does not pick its alpha.
enum HopGlassTier {
  /// Floating chrome — the top pill, the bottom nav. Carries titles, icons and
  /// a badge: big glyphs, brief attention. Fill: [HoppinColors.glass] (72%).
  chrome,

  /// A modal sheet. Carries mid-emphasis body copy that someone READS, so it
  /// needs a denser fill to clear AA — the chrome tier measures 3.94:1 for dark
  /// secondary text over the worst backdrop a sheet floats above.
  /// Fill: [HoppinColors.glassSheet] (86%).
  sheet,
}

class HopGlass extends StatelessWidget {
  /// Creates a frosted pane.
  const HopGlass({
    required this.borderRadius,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.floating = true,
    this.tier = HopGlassTier.chrome,
    super.key,
  });

  /// The pane's duty, which selects its fill token. See [HopGlassTier] — a
  /// surface picks a duty, never an alpha.
  final HopGlassTier tier;

  /// The pane's corners. For the top bar this is a true pill
  /// (`chrome.pillRadius`); for the anchored nav it is squared at the bottom
  /// where it meets the screen edge.
  final BorderRadius borderRadius;

  /// The pane's contents. Painted OVER the blur, at full opacity — the glass
  /// is behind the text, never in front of it.
  final Widget child;

  /// Space between the pane and whatever bounds it.
  ///
  /// 🔴 This is AIR, and air does not absorb touches. When the pane is layered
  /// over content (which is the only way its blur means anything), the margin
  /// band sits on top of that content — and a plain `Padding` still hit-tests
  /// across its own inset, so the gap around a floating pill silently eats every
  /// tap that lands in it. The screen looks immaculate and the row beneath the
  /// bar's margin is simply dead. See the note on [build].
  final EdgeInsets margin;

  /// Whether the pane casts. A pill detached from every edge must
  /// ([HoppinShadows.glass]); the nav, welded to the bottom of the screen, gets
  /// only its rim — a drop shadow on a surface with nothing under it is a
  /// smudge.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final chrome = hoppin.chrome;
    final sigma = chrome.blurSigma;
    final fill = switch (tier) {
      HopGlassTier.chrome => colors.glass,
      HopGlassTier.sheet => colors.glassSheet,
    };

    // Blur FIRST, then re-saturate what the blur just averaged into mud.
    //
    // The order is not cosmetic. `compose(outer:, inner:)` runs the inner filter
    // first, so the matrix operates on the already-blurred pixels — which is the
    // only order that means anything: saturating BEFORE the blur just gives the
    // averaging step more colourful mud to average.
    final frost = ui.ImageFilter.compose(
      outer: ui.ColorFilter.matrix(chrome.saturationMatrix),
      inner: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );

    // 🔴 THE MARGIN MUST NOT SWALLOW TAPS.
    //
    // A `Padding` hit-tests its whole box, inset included. Over layered content
    // that means the ring of air around a floating pill silently eats every tap
    // that lands in it — the pill is 64pt tall but occupies a 96pt band, so a
    // 32pt strip of the page underneath is dead to the touch while looking
    // perfectly alive. (`upload_wiring_test` caught precisely this: a document
    // row scrolled to the top of its list became untappable, and the tap was
    // being absorbed by nothing at all.)
    //
    // The padding stays — the pill must still be laid out detached — but the
    // pane below only receives pointers where it actually PAINTS.
    return Padding(
      padding: margin,
      child: DecoratedBox(
        // The cast sits OUTSIDE the clip — a shadow drawn inside the ClipRRect
        // is clipped away by the very shape that is meant to be casting it.
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: floating ? HoppinShadows.glass(colors.glassShadow) : null,
        ),
        // The backdrop pass is expensive and its geometry never changes, so it
        // gets its own layer: without this, anything repainting nearby drags the
        // blur through a re-rasterise it did not need.
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: borderRadius,
            // 🔴 `.grouped`, not the plain constructor — a free 40-60% back.
            //
            // Every BackdropFilter normally rasterises its OWN copy of the
            // backdrop. The rider shell floats two panes (the top pill and the
            // bottom nav) over one scrolling page, which means the same page was
            // being sampled and blurred twice per frame — two saveLayers, two
            // sigma-18 passes, for two panes that see the same content. On the
            // mid-range Android the driver app lives on for 8-hour shifts, one
            // full-width blur at this sigma is already ~6-9ms against a 16.67ms
            // budget; two is the frame.
            //
            // `.grouped` shares one rasterised backdrop between every pane under
            // the nearest [BackdropGroup] ancestor. It resolves that ancestor
            // implicitly, so this stays an internal detail: HopGlass's public API
            // does not grow a parameter, call sites do not change, and a pane
            // with no BackdropGroup above it simply behaves as before. The shell
            // opts in by wrapping its chrome Stack; nothing else has to know.
            child: BackdropFilter.grouped(
              filter: frost,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: borderRadius,
                  border: Border.all(color: colors.glassEdge),
                ),
                // The SPECULAR HINT. A real pane is lit from above, so its top
                // face catches more light than its bottom one — a uniform rim
                // is the tell of a drawn rectangle rather than a held object.
                // This is a fill, not a second border: a gradient that fades to
                // nothing by ~40% of the height, so it brightens the top arc and
                // leaves the rest of the glass alone. Costs one gradient in a
                // layer that is already being composited.
                //
                // 🔴 The peak is [HoppinColors.glassSpecular] — its OWN token,
                // not a factor of the rim. It used to be `glassEdge * 0.45`, and
                // that coupling is why dark had no highlight: a 14% rim put the
                // specular at white @6.3%, under the ~10% where a gradient reads
                // as light rather than as banding. One conservative rim value
                // silently broke two optical properties. A rim is light caught
                // on an EDGE; a specular is light off a FACE. Different physics,
                // different tokens.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.glassSpecular,
                        colors.glassSpecular.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.4],
                    ),
                  ),
                  // The UNDER-RIM: the pane's own thickness, in shadow.
                  //
                  // The bright rim above draws all four edges the same, and a
                  // uniform outline is a drawn rectangle. A slab lit from above
                  // has a NEAR face and a FAR one — the bottom arc falls into
                  // the shadow the top arc is casting through the material. This
                  // gradient is that shadow: it lives in the bottom ~30%, it is
                  // navy in light rather than black (black on a cool-white page
                  // is a dirty groove, not a shadow), and it is the difference
                  // between an outlined region and an object with thickness.
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          colors.glassUnderRim,
                          colors.glassUnderRim.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.3],
                      ),
                    ),
                    // THE INNER STROKE — the pane's far wall.
                    //
                    // Everything above this line describes the pane's FRONT
                    // face. A slab has a back one too, and you see it through
                    // the material: the inside of the far edge catches the same
                    // light the rim does, one thickness in. Without it the glass
                    // has a boundary but no DEPTH — a filter applied to a
                    // region, which is exactly what it was.
                    //
                    // 🔴 IT PAINTS, IT DOES NOT LAY OUT. The obvious way to
                    // inset a second border is a `Padding`, and it is wrong: the
                    // pane's children are positioned against the pane's EDGE,
                    // and the top bar's avatar is CONCENTRIC with the pill by a
                    // derived identity (avatarInset == pillRadius - avatarRadius
                    // == 8, see HoppinChrome). A 1px pad silently pushed that to
                    // 9 and broke the one relationship the owner asked for by
                    // name — `hop_top_bar_test` caught it. Decoration is not
                    // allowed to move geometry: this sits in a
                    // non-layout-affecting overlay via a Stack, so the far wall
                    // is painted over the pane's own bounds and the child's box
                    // is exactly the box it was before.
                    child: Stack(
                      children: [
                        child,
                        // The far wall, painted 1px in from the rim, at a
                        // fraction of its strength — the light crosses the
                        // material to get here, so it arrives weaker.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Padding(
                              padding: const EdgeInsets.all(1),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: borderRadius,
                                  border: Border.all(
                                    color: colors.glassEdge.withValues(
                                      alpha: colors.glassEdge.a * 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
