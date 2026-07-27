import 'package:flutter/material.dart';

import '../theme/context_extension.dart';
import '../tokens/spacing.dart';

/// A ride-type option card (Figma: Standard / Estate / MPV / Minibus grid).
///
/// Radius `radii.card` (10). Unselected = white surface + the soft card
/// shadow. Selected = `selectedTint` fill + a 1px navy (`selectedBorder`)
/// border, shadow suppressed. A vehicle [icon] tops the [name] (Poppins
/// Medium ~16 navy) over the [capacity] line (Poppins ~12 textMid).
class RideTypeCard extends StatelessWidget {
  /// Creates a ride-type card.
  const RideTypeCard({
    required this.name,
    required this.capacity,
    required this.icon,
    required this.onTap,
    this.selected = false,
    super.key,
  });

  /// Vehicle class name — "Standard", "MPV", …
  final String name;

  /// Seats/bags line — "4 seats • Upto 2 bags".
  final String capacity;

  /// Vehicle glyph shown above the name.
  final IconData icon;

  /// Selection state — drives the tint + navy border.
  final bool selected;

  /// Tap handler; the parent owns the single-selection state.
  ///
  /// Nullable: a **null** handler renders the card inert (no ink, no tap).
  /// That is a real state, not a degenerate one — a vehicle class the app
  /// cannot currently book must still be *shown* (it is a real product) while
  /// being unselectable, rather than presented as an equal peer of the classes
  /// that work. See `RideTypeOption.bookable` in the rider app.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final radius = BorderRadius.circular(hoppin.radii.card);
    // Dark cards separate from the page by LINE, not by shadow (an 8%-black
    // cast over a #0F1220 canvas is invisible) — see HoppinColors.cardBorder.
    // In light that token is transparent, and a transparent side is NOT the same
    // as no side: it still paints. Light means none.
    final side = switch ((selected, colors.cardBorder.a)) {
      (true, _) => BorderSide(color: colors.selectedBorder),
      (false, 0) => BorderSide.none,
      (false, _) => BorderSide(color: colors.cardBorder),
    };
    final shape = RoundedRectangleBorder(borderRadius: radius, side: side);

    final surface = Material(
      color: selected ? colors.selectedTint : colors.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: EdgeInsets.all(hoppin.spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: colors.accent),
              SizedBox(height: hoppin.spacing.sm),
              // These cards sit three-across in a row, so the widest name the
              // product has ("Accessibility") is wider than the card. Left to
              // wrap it broke as "Accessibilit / y" — a word split mid-letter,
              // on the app's landing screen, in the shipping build. A name is a
              // LABEL: it gets one line and an ellipsis, never a hyphen-less
              // fracture.
              Text(
                name,
                style: hoppin.type.bodyMedium.copyWith(color: colors.textHi),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
              SizedBox(height: hoppin.spacing.xs),
              // The capacity line is a SENTENCE and may wrap — but it is capped,
              // so a long one cannot silently grow the card past its peers and
              // leave the row ragged.
              Text(
                capacity,
                style: hoppin.type.metaSmall.copyWith(color: colors.textMid),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: selected ? null : HoppinShadows.card,
      ),
      child: surface,
    );
  }
}
