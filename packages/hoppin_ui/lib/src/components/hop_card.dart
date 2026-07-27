import 'package:flutter/material.dart';

import '../theme/context_extension.dart';
import '../tokens/spacing.dart';

/// The Hoppin resting surface (Figma): card colour, radius `radii.card` (10),
/// and a soft [HoppinShadows.card] offset shadow.
///
/// The resting EDGE is theme-dependent, via `colors.cardBorder`. Light gets
/// none — the Figma card carries its elevation with a shadow, and a border on
/// top of that only muddies it. Dark gets a hairline, because a shadow on a dark
/// surface is not a subtle cue, it is an invisible one: 8% black over a #0F1220
/// canvas simply does not render, and the cards were floating on nothing.
///
/// Provide [onTap] to make the whole card tappable with a matching-radius
/// ink response. [selected] lifts the card to the `selectedTint` fill with a
/// 1px navy border (the Figma selected-card treatment).
class HopCard extends StatelessWidget {
  /// Creates a Hoppin card around [child].
  const HopCard({
    required this.child,
    this.onTap,
    this.selected = false,
    this.padding,
    super.key,
  });

  /// Card content.
  final Widget child;

  /// Optional tap handler — when provided the card is an ink target.
  final VoidCallback? onTap;

  /// Selected treatment: `selectedTint` fill + 1px navy border, shadow
  /// suppressed (the Figma selected card sits flat under its border).
  final bool selected;

  /// Inner padding; defaults to `EdgeInsets.all(spacing.lg)`.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final radius = BorderRadius.circular(hoppin.radii.card);
    // `cardBorder` is TRANSPARENT in light, and a transparent BorderSide is not
    // the same thing as no BorderSide: it still paints (an invisible 1px line
    // that eats a pixel of the fill and rounds the antialiasing differently).
    // Light means NONE.
    final side = switch ((selected, colors.cardBorder.a)) {
      (true, _) => BorderSide(color: colors.selectedBorder),
      (false, 0) => BorderSide.none,
      (false, _) => BorderSide(color: colors.cardBorder),
    };
    final shape = RoundedRectangleBorder(borderRadius: radius, side: side);

    final body = Padding(
      padding: padding ?? EdgeInsets.all(hoppin.spacing.lg),
      child: child,
    );

    final surface = Material(
      color: selected ? colors.selectedTint : colors.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(onTap: onTap, customBorder: shape, child: body),
    );

    // The soft Figma card shadow lives on a wrapping Container so the
    // Material's own shape stays flat (elevation 0) — the shadow is the
    // elevation cue, never a Material tint.
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: selected ? null : HoppinShadows.card,
      ),
      child: surface,
    );
  }
}
