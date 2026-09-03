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
        GlassTier.chrome => 16,
        GlassTier.panel => 24,
      };

  /// How opaque the fill is. A panel carries readable copy, so it is denser.
  double get _fill => switch (tier) {
        GlassTier.chrome => 0.72,
        GlassTier.panel => 0.86,
      };

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20);
    final base = tint ?? AppColors.surface;

    // The OS switch wins. `prefers-reduced-transparency` maps to
    // `highContrast` on the platforms Flutter surfaces it for, and a driver
    // who set it gets a solid surface rather than a prettier unreadable one.
    final reduceTransparency = MediaQuery.highContrastOf(context);

    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: reduceTransparency ? base : base.withValues(alpha: _fill),
        borderRadius: radius,
        // The lit edge. A single hairline at ~40% white is what separates
        // frosted glass from a flat translucent box: it catches the light the
        // surface is supposedly bending.
        border: Border.all(
          color: reduceTransparency
              ? AppColors.border
              : Colors.white.withValues(alpha: 0.42),
        ),
      ),
      child: child,
    );

    if (reduceTransparency) {
      return DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: _cast),
        child: ClipRRect(borderRadius: radius, child: body),
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
          filter: ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma),
          child: body,
        ),
      ),
    );
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
