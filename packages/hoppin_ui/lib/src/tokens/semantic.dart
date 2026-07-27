import 'package:flutter/material.dart';

import '../theme/hoppin_colors.dart';
import 'primitives.dart';

/// Which Hoppin app a theme is being built for. The rider revamp (v1.1)
/// collapses the two lanes onto one Figma navy ink; the enum is kept so the
/// driver revamp can re-diverge accents in its own milestone.
enum HoppinApp {
  /// Rider app.
  rider,

  /// Driver app.
  driver,
}

/// Internal semantic resolver: (app, brightness) → every [HoppinColors]
/// field, wired to the Figma "Passenger View" palette. Not exported from the
/// barrel — theme builders consume it; app code reads the result via
/// `context.hoppin.colors`.
///
/// Light = pixel-faithful to Figma. Dark = derived from the same tokens
/// (Figma draws light only). In R1 both apps resolve identical values.
HoppinColors hoppinSemanticColors(HoppinApp app, Brightness brightness) {
  final dark = brightness == Brightness.dark;

  return HoppinColors(
    accent: dark ? HoppinPrimitives.inkOnDark : HoppinPrimitives.ink,
    onAccent: dark ? HoppinPrimitives.canvasDark : HoppinPrimitives.cardLight,
    accentSubtle: dark
        ? HoppinPrimitives.selectedTintDark
        : HoppinPrimitives.selectedTintLight,
    canvas: dark ? HoppinPrimitives.canvasDark : HoppinPrimitives.canvasLight,
    card: dark ? HoppinPrimitives.cardDark : HoppinPrimitives.cardLight,
    selectedTint: dark
        ? HoppinPrimitives.selectedTintDark
        : HoppinPrimitives.selectedTintLight,
    selectedBorder: dark ? HoppinPrimitives.inkOnDark : HoppinPrimitives.ink,
    raised: dark ? HoppinPrimitives.cardDark : HoppinPrimitives.cardLight,
    hairline: dark
        ? HoppinPrimitives.hairlineDark
        : HoppinPrimitives.hairlineLight,
    textHi: dark ? HoppinPrimitives.textHiDark : HoppinPrimitives.textHiLight,
    textMid: dark ? HoppinPrimitives.textMidDark : HoppinPrimitives.textMidLight,
    success: HoppinPrimitives.successGreen,
    successSubtle: dark
        ? HoppinPrimitives.successSubtleDark
        : HoppinPrimitives.successSubtleLight,
    // `warn` retained as a field (legacy consumers); repointed to brand red
    // until the token set is pruned post-R1.
    warn: HoppinPrimitives.red,
    warnSubtle: dark
        ? HoppinPrimitives.alertSurfaceDark
        : HoppinPrimitives.alertSurfaceLight,
    error: dark ? HoppinPrimitives.alertRed : HoppinPrimitives.red,
    errorSubtle: dark
        ? HoppinPrimitives.alertSurfaceDark
        : HoppinPrimitives.alertSurfaceLight,
    plateBg: dark ? HoppinPrimitives.plateWhite : HoppinPrimitives.plateYellow,
    plateText: HoppinPrimitives.plateChars,
    scrim: HoppinPrimitives.scrimBase.withValues(alpha: dark ? 0.55 : 0.40),
    // Glass — the ONLY translucent roles in the map. See HoppinColors.glass:
    // these are painted over a live BackdropFilter, so the alpha is what makes
    // the material read as frosted rather than as a tinted card.
    glass: dark ? HoppinPrimitives.glassDark : HoppinPrimitives.glassLight,
    // The SHEET tier of the same material — denser, because a sheet carries
    // body copy and the chrome tier's 72% puts dark textMid under AA (3.94:1).
    glassSheet: dark
        ? HoppinPrimitives.glassSheetDark
        : HoppinPrimitives.glassSheetLight,
    glassEdge: dark
        ? HoppinPrimitives.glassEdgeDark
        : HoppinPrimitives.glassEdgeLight,
    glassSpecular: dark
        ? HoppinPrimitives.glassSpecularDark
        : HoppinPrimitives.glassSpecularLight,
    glassUnderRim: dark
        ? HoppinPrimitives.glassUnderRimDark
        : HoppinPrimitives.glassUnderRimLight,
    glassShadow: dark
        ? HoppinPrimitives.glassShadowDark
        : HoppinPrimitives.glassShadowLight,
    // Cards separate from the page by SHADOW in light and by LINE in dark.
    // Not a preference — a shadow is 8% black, and 8% black over a #0F1220
    // canvas is nothing. See HoppinColors.cardBorder.
    cardBorder: dark ? HoppinPrimitives.hairlineDark : Colors.transparent,
  );
}
