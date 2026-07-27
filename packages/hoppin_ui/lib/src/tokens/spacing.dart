import 'package:flutter/material.dart';

import 'primitives.dart';

/// Spacing scale — brightness-invariant statics, no ThemeExtension ceremony.
/// The 24pt gutter is the page-margin constant of the surface language.
abstract final class HoppinSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double gutter = 24.0;
  static const double xl = 32.0;
}

/// Corner radii — Figma: 10 cards / 12 controls (chips, buttons) / pills.
/// Legacy values (input 8, sheet 16, plate 5) retained for un-converted
/// components; pruned once every screen adopts the Figma radii.
abstract final class HoppinRadii {
  static const double card = 10.0;
  static const double control = 12.0;
  static const double pillSmall = 20.0;
  static const double pill = 100.0;
  static const double input = 8.0;
  static const double sheet = 16.0;
  static const double plate = 5.0;
}

/// Card elevation — Figma resting cards use a soft offset shadow
/// (`2px 2px 6px 1px rgba(0,0,0,0.08)`); the fare/nav surfaces use the
/// slightly stronger `…0.1` variant.
abstract final class HoppinShadows {
  static const card = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000), // ~8% black
      offset: Offset(2, 2),
      blurRadius: 6,
      spreadRadius: 1,
    ),
  ];
  static const cardStrong = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A000000), // ~10% black
      offset: Offset(2, 2),
      blurRadius: 6,
      spreadRadius: 1,
    ),
  ];

  /// The cast of a FLOATING glass surface (the top pill, the bottom nav).
  ///
  /// Two layers, both centred rather than offset diagonally: a floating pill
  /// has no attached edge, so a directional card shadow makes it look glued to
  /// the corner it leans away from. A tight contact shadow reads as "held just
  /// off the page"; a wide ambient one reads as "held ABOVE the page". You need
  /// both, or it looks either pasted on or unmoored.
  ///
  /// [shadow] is theme-resolved (`colors.glassShadow`) — dark needs a deeper
  /// cast, because 12% black over a #0F1220 canvas is nothing at all.
  static List<BoxShadow> glass(Color shadow) => <BoxShadow>[
    BoxShadow(
      color: shadow,
      offset: const Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: shadow.withValues(alpha: shadow.a * 0.5),
      offset: const Offset(0, 2),
      blurRadius: 6,
      spreadRadius: -2,
    ),
  ];
}

/// The GEOMETRY of the frosted chrome — and, in particular, the one
/// relationship the owner asked for by name.
///
/// 🔴 **The concentric avatar.** The avatar on the right of the top pill must
/// be a perfect concentric circle nested inside the pill's own curvature: the
/// two arcs share a centre-line and the gap between them is uniform all the way
/// round. It must look CUT FROM THE SAME ARC, not dropped on top.
///
/// That is not a look you can eyeball into place with a hand-picked padding —
/// it is an identity, and the moment someone nudges the bar height by 2px a
/// hardcoded inset silently breaks it. So it is DERIVED here and asserted in
/// `hop_top_bar_test`:
///
/// ```text
///   pillRadius   = barHeight / 2          = 32
///   avatarRadius = avatarSize / 2         = 24
///   avatarInset  = pillRadius − avatarRadius
///                = (barHeight − avatarSize) / 2
///                = 8            ← uniform, on every side
/// ```
///
/// Concentricity holds iff the avatar's inset from the pill edge is the same
/// on the top, bottom and trailing edges AND equals the difference of the two
/// radii. Change [barHeight] or [avatarSize] and every other number here moves
/// with it; the relationship cannot drift.
abstract final class HoppinChrome {
  /// The floating pill's height. Its radius is half this — it is a TRUE pill
  /// (see [pillRadius]), not a rounded rectangle with a taste-picked corner.
  static const double barHeight = 64.0;

  /// The avatar's diameter. Must be < [barHeight], or there is no gap to be
  /// uniform.
  static const double avatarSize = 48.0;

  /// Half [barHeight] — a stadium. Anything less and the "concentric" arc the
  /// avatar is supposed to nest inside does not exist.
  static double get pillRadius => barHeight / 2;

  /// Half [avatarSize].
  static double get avatarRadius => avatarSize / 2;

  /// The uniform gap between the pill's arc and the avatar's, on EVERY side.
  /// Equal to `pillRadius - avatarRadius` by construction — that equality is
  /// what concentricity *means*.
  static double get avatarInset => (barHeight - avatarSize) / 2;

  /// Gap from the screen edge to the floating pill (left, right and — added to
  /// the status-bar inset — above). The pill is DETACHED: it floats over the
  /// content, it is not welded to the top of the page.
  static const double pillMargin = HoppinSpacing.lg;

  /// Blur sigma for both frosted bars. One constant, deliberately: two
  /// different sigmas would read as two different materials.
  static const double blurSigma = HoppinPrimitives.glassBlurSigma;

  /// How much chroma the glass puts BACK after the blur took it out.
  ///
  /// A blur averages colour toward grey, so a pure-blur pane reads muddy. The
  /// material is only convincing if the saturation is restored on the far side
  /// of it — see [HoppinPrimitives.glassSaturation] for why the number is 1.6
  /// and not the 1.8 the CSS recipes quote.
  static const double saturation = HoppinPrimitives.glassSaturation;

  /// The colour matrix that applies [saturation], for composing over the blur.
  ///
  /// This is the standard luminance-preserving saturation matrix: each output
  /// channel mixes the pixel's own LUMA with its original value, weighted by
  /// [saturation]. At `s = 1` it is the identity; at `s = 0` it is greyscale; at
  /// `s > 1` it pushes each channel away from luma, which is what "more vivid"
  /// physically means.
  ///
  /// The luma weights are Rec.601 (0.213 / 0.715 / 0.072) — the same ones CSS
  /// `saturate()` uses, so the material matches the reference recipe rather than
  /// a lookalike. Green carries most of the weight because the eye does.
  ///
  /// Deriving it (rather than hand-typing 20 floats) is the point: a matrix
  /// typed out by hand is a matrix nobody can re-tune, and the first person to
  /// try shifts the neutrals without noticing.
  static List<double> saturationMatrix([double s = saturation]) {
    const lumaR = 0.213;
    const lumaG = 0.715;
    const lumaB = 0.072;
    final invR = lumaR * (1 - s);
    final invG = lumaG * (1 - s);
    final invB = lumaB * (1 - s);
    return <double>[
      invR + s, invG, invB, 0, 0, //
      invR, invG + s, invB, 0, 0, //
      invR, invG, invB + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// Vertical space a scrolling tab must reserve at its TOP so its first item
  /// is not permanently parked under the floating pill. (The pill's own top
  /// margin is a safe-area inset the screen already has.)
  static double get scrollPaddingTop => barHeight + pillMargin * 2;

  /// Vertical space a scrolling tab must reserve at its BOTTOM so its last item
  /// clears the anchored glass nav. Safe-area bottom is added on top of this by
  /// the nav itself.
  static const double scrollPaddingBottom = 96.0;
}
