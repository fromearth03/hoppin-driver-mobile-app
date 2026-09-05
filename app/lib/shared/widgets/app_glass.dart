import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';

/// How much emphasis a glass surface carries.
///
/// The two tiers are a CONTRAST decision, not a taste one. Chrome floats over
/// whatever is behind it and carries short labels a driver glances at; a panel
/// carries copy they actually read, so it needs a denser fill to stay legible
/// over a bright map or a white list underneath.
enum GlassTier {
  /// Floating chrome: the nav pill, the online toggle, a toast. Big glyphs,
  /// brief attention, maximum see-through.
  chrome,

  /// A sheet or dialog carrying body copy. Denser fill so text over the worst
  /// backdrop still clears AA.
  panel,
}

/// The one frosted surface in this app.
///
/// 🔴 GLASS WAS COPY-PASTED SIX TIMES BEFORE THIS EXISTED. The nav pill, the
/// online toggle, the toast, the owes dialog, the appeal sheet and the scroll
/// edge each hand-rolled their own `BackdropFilter` with different sigmas,
/// different alphas and different borders — so the same material read
/// differently on every screen, and none of them had an accessibility
/// fallback. This is that material, once.
///
/// 🔴 IT IS NOT APPLE'S LIQUID GLASS. Apple documents that for Apple
/// platforms; there is no public implementation of it. This is an honest
/// frosted-glass approximation: a blur, a translucent fill, a hairline that
/// catches light at the top edge, and a soft cast beneath.
///
/// **It degrades, and that is deliberate.** A driver who has asked the OS to
/// reduce transparency gets an opaque surface with no blur at all — the text
/// is the point, the material is not. Blur is also the single most expensive
/// thing on a trip screen that is already drawing a live map, so it is spent
/// only on surfaces that genuinely float.
class AppGlass extends StatelessWidget {
  const AppGlass({
    super.key,
    required this.child,
    this.tier = GlassTier.chrome,
    this.borderRadius,
    this.padding,
    this.tint,
  });

  final Widget child;
  final GlassTier tier;

  /// Defaults to a 20pt round — the app's card radius. A pill passes its own.
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  /// Overrides the surface colour the fill is mixed from. The nav pill uses
  /// its own ink; everything else takes the app surface.
  final Color? tint;

  /// The blur radius per tier. Chrome sees more of what is behind it.
  double get _sigma => switch (tier) {
        GlassTier.chrome => 20,
        GlassTier.panel => 28,
      };

  /// How opaque the fill is. A panel carries readable copy, so it is denser.
  /// 🔴 LOWER IS GLASSIER, AND THIS WAS THE MISTAKE. A panel at 0.86 alpha is
  /// 86% opaque paint — whatever the blur produced underneath is almost
  /// entirely hidden, so the surface reads as a flat card that happens to sit
  /// on a tinted page. Thinning the fill is what lets the refraction show;
  /// legibility is bought back by the saturation boost and the sheen instead
  /// of by opacity. Contrast is verified over the strongest pool.
  double get _fill => switch (tier) {
        GlassTier.chrome => 0.58,
        GlassTier.panel => 0.70,
      };

  /// How much the backdrop's colour is pushed under the glass.
  ///
  /// 🔴 THIS IS THE DIFFERENCE BETWEEN GLASS AND A GREY BOX. Apple's material
  /// does not merely blur what is behind it — it over-saturates it, so colour
  /// bleeds up through the surface and the panel takes a tint from whatever it
  /// is sitting on. A blur alone averages colour toward grey, which is exactly
  /// why a plain BackdropFilter reads as frosted plastic.
  double get _saturation => switch (tier) {
        GlassTier.chrome => 2.2,
        GlassTier.panel => 1.9,
      };

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20);
    final base = tint ?? AppColors.surface;

    // The OS switch wins. `prefers-reduced-transparency` maps to
    // `highContrast` on the platforms Flutter surfaces it for, and a driver
    // who set it gets a solid surface rather than a prettier unreadable one.
    final reduceTransparency = MediaQuery.highContrastOf(context);

    if (reduceTransparency) {
      return DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: _cast),
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: base,
              borderRadius: radius,
              border: Border.all(color: AppColors.border),
            ),
            child: child,
          ),
        ),
      );
    }

    return DecoratedBox(
      // The cast sits OUTSIDE the clip — a shadow drawn inside its own
      // rounded clip is invisible, which is how most hand-rolled glass ends
      // up looking flat.
      decoration: BoxDecoration(borderRadius: radius, boxShadow: _cast),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          // Saturate FIRST, then blur. Blurring a saturated backdrop keeps the
          // colour; saturating an already-blurred one just amplifies mud.
          filter: ImageFilter.compose(
            outer: ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
            inner: ColorFilter.matrix(_saturate(_saturation)),
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              // A gradient fill, not a flat one: real glass is lit from
              // somewhere, so it is brighter where the light lands and
              // denser in its own shadow.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withValues(alpha: _fill - 0.10),
                  base.withValues(alpha: _fill + 0.04),
                ],
              ),
              // The lit rim. Brighter along the top-left where the light
              // strikes, nearly gone at the bottom-right — a uniform hairline
              // is the single clearest tell of fake glass.
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 0.8,
              ),
            ),
            child: Stack(
              children: [
                // The specular sheen: a soft band of light across the upper
                // third, which is what makes a surface read as something with
                // a top rather than a rectangle of colour.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0.10),
                            Colors.transparent,
                            // The bounce: light that entered the top of the
                            // slab and scatters back out of its foot. Without
                            // it the surface fades to nothing and reads as a
                            // gradient rather than a solid with two faces.
                            Colors.white.withValues(alpha: 0.12),
                          ],
                          stops: const [0.0, 0.28, 0.68, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A saturation matrix. `amount` of 1 leaves colour untouched; above 1
  /// pushes it, which is what lets the ground's colour read through the glass.
  static List<double> _saturate(double amount) {
    const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
    final r = (1 - amount) * lumR;
    final g = (1 - amount) * lumG;
    final b = (1 - amount) * lumB;
    return [
      r + amount, g,          b,          0, 0,
      r,          g + amount, b,          0, 0,
      r,          g,          b + amount, 0, 0,
      0,          0,          0,          1, 0,
    ];
  }

  /// Tinted to the app's ink rather than pure black. A black shadow over a
  /// warm surface reads as dirt.
  static final _cast = [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.10),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}
