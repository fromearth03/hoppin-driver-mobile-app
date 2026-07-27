import 'package:flutter/material.dart';

import '../theme/context_extension.dart';
import 'hop_glass.dart';

/// The Hoppin modal sheet surface: top radius `radii.sheet`, FROSTED GLASS, a
/// centered 36x4 hairline drag handle, and the one ambient veil the surface
/// language allows — a single drawn [BoxShadow] beneath it.
///
/// 🔴 **It is glass, and it is glass at the SHEET tier** ([HopGlassTier.sheet]),
/// not the chrome tier the bars use. A sheet carries mid-emphasis body copy that
/// someone actually reads; the chrome's 72% fill measures 3.94:1 for dark
/// secondary text over the worst backdrop a sheet floats above, which is under
/// AA. The denser fill is the floor's decision, not a taste one — see
/// [HoppinColors.glassSheet].
///
/// The blur has something to sample because a modal route paints OVER the page:
/// the sheet floats above the scrim, which floats above the live screen. That is
/// the same layering bargain the shell makes, handed to us for free by the
/// navigator — which is exactly why a sheet is the right second home for this
/// material and a `Column`-stacked panel would not be.
///
/// Use [HopSheet.show] to present it modally over the scrim; the widget is
/// also embeddable directly for persistent bottom surfaces.
class HopSheet extends StatelessWidget {
  /// Creates an embeddable sheet surface around [child].
  const HopSheet({required this.child, this.padding, super.key});

  /// Sheet content, laid out below the drag handle.
  final Widget child;

  /// Content padding; defaults to `EdgeInsets.all(spacing.gutter)`.
  final EdgeInsetsGeometry? padding;

  /// Presents a [HopSheet] as a modal bottom sheet: scrim-token barrier,
  /// transparent Material chrome (the HopSheet container draws the surface
  /// and its ambient veil itself), zero elevation, safe-area aware.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isDismissible = true,
  }) {
    final colors = context.hoppin.colors;
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      useSafeArea: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      barrierColor: colors.scrim,
      builder: (sheetContext) => HopSheet(child: builder(sheetContext)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.vertical(
      top: Radius.circular(hoppin.radii.sheet),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // NO fill here any more — the glass draws the surface. A colour on this
        // box would sit UNDER the blur and defeat it: the pane would be sampling
        // an opaque slab of card, which is a very expensive way to render a
        // card. The box now exists only to cast.
        borderRadius: radius,
        // The one ambient veil: a static drawn shadow — warm black via the
        // scrim base token, stronger in dark where the canvas swallows it.
        // It sits OUTSIDE the glass clip, as every cast must.
        boxShadow: [
          BoxShadow(
            color: colors.scrim.withValues(alpha: dark ? 0.45 : 0.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: HopGlass(
        borderRadius: radius,
        // The SHEET tier: body copy needs a denser pane than a nav bar does.
        tier: HopGlassTier.sheet,
        // The sheet is welded to the bottom of the screen and already casts (the
        // veil above). A second shadow from the glass would double it.
        floating: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(top: hoppin.spacing.sm),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.hairline,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            Padding(
              padding: padding ?? EdgeInsets.all(hoppin.spacing.gutter),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
