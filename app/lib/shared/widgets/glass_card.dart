import 'package:flutter/material.dart';

import 'app_glass.dart';

/// The app's content card, as glass.
///
/// Every screen previously hand-rolled `Container(color: white, radius, border)`
/// — a flat card on a flat ground, which is why the only glass in the app was
/// the nav pill. This is the same card built on [AppGlass], so it picks up the
/// [AppAmbience] wash behind it and the material is consistent everywhere.
///
/// Use [GlassTier.panel] (the default) for anything carrying copy a driver
/// reads. [GlassTier.chrome] is for surfaces that float over live content — a
/// map overlay, a pill — where seeing through matters more than density.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 20,
    this.tier = GlassTier.panel,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final GlassTier tier;

  /// When set the whole card is tappable, with a ripple clipped to its round.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    final surface = AppGlass(
      tier: tier,
      borderRadius: borderRadius,
      padding: onTap == null ? padding : null,
      child: onTap == null
          ? child
          // The ink has to sit INSIDE the glass so the ripple is clipped to
          // the card's round; a Material wrapped around the outside would
          // paint its own opaque rectangle and kill the blur.
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: Padding(padding: padding, child: child),
              ),
            ),
    );

    return surface;
  }
}
