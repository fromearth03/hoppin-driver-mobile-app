import 'package:flutter/material.dart';

import '../tokens/semantic.dart';
import '../tokens/spacing.dart';
import 'hoppin_colors.dart';
import 'hoppin_motion.dart';
import 'hoppin_typography.dart';

/// The four Hoppin themes — rider/driver x light/dark — all built from one
/// semantic map wired to the Figma "Passenger View" palette.
///
/// The [ColorScheme] is HAND-BUILT, never seeded: seed-derived palettes
/// re-tone the brand hex, and the Figma navy ink (#181C3A) must survive
/// exactly. Every theme carries [HoppinColors] and [HoppinMotion] as
/// extensions — widgets consume them via `context.hoppin`.
///
/// Light is pixel-faithful to Figma; dark is derived from the same tokens.
/// In the v1.1 rider revamp both apps resolve one navy accent (the driver
/// lane re-diverges in its own milestone).
abstract final class HoppinTheme {
  /// Rider app, light — Figma navy on cool white.
  static ThemeData riderLight() => _build(HoppinApp.rider, Brightness.light);

  /// Rider app, dark — derived cool-dark ramp.
  static ThemeData riderDark() => _build(HoppinApp.rider, Brightness.dark);

  /// Driver app, light — same navy (lane re-diverges in the driver revamp).
  static ThemeData driverLight() => _build(HoppinApp.driver, Brightness.light);

  /// Driver app, dark — derived cool-dark ramp.
  static ThemeData driverDark() => _build(HoppinApp.driver, Brightness.dark);

  static ThemeData _build(HoppinApp app, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final c = hoppinSemanticColors(app, brightness);
    final opposite = hoppinSemanticColors(
      app,
      dark ? Brightness.light : Brightness.dark,
    );

    // Hairline-strong: mid text pulled toward canvas, precomputed opaque.
    final outline = Color.alphaBlend(
      c.textMid.withValues(alpha: 0.55),
      c.canvas,
    );

    final scheme = ColorScheme(
      brightness: brightness,
      // Accent lanes — both point at the lane accent; Hoppin has one accent
      // per app, not a secondary hue.
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSubtle,
      onPrimaryContainer: c.accent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.accentSubtle,
      onSecondaryContainer: c.accent,
      // Tertiary carries the success lane (positive money moments).
      tertiary: c.success,
      onTertiary: c.onAccent,
      tertiaryContainer: c.successSubtle,
      onTertiaryContainer: c.success,
      error: c.error,
      onError: c.onAccent,
      errorContainer: c.errorSubtle,
      onErrorContainer: c.error,
      // Surfaces — canvas base, card tier, raised tier (light collapses
      // card/raised to white; hierarchy is carried by hairlines there).
      surface: c.canvas,
      onSurface: c.textHi,
      onSurfaceVariant: c.textMid,
      surfaceDim: c.canvas,
      surfaceBright: dark ? c.raised : c.card,
      surfaceContainerLowest: c.card,
      surfaceContainerLow: c.card,
      surfaceContainer: c.card,
      surfaceContainerHigh: dark ? c.raised : c.card,
      surfaceContainerHighest: dark ? c.raised : c.card,
      outline: outline,
      outlineVariant: c.hairline,
      // Shadow lane only — never a painted surface.
      shadow: const Color(0xFF000000),
      scrim: c.scrim,
      // Own textHi IS the opposite-polarity surface.
      inverseSurface: c.textHi,
      onInverseSurface: c.canvas,
      inversePrimary: opposite.accent,
      // Kill M3 elevation tinting — surfaces are flat by design.
      surfaceTint: Colors.transparent,
    );

    // Figma type roles mapped onto the Material text slots.
    final textTheme = TextTheme(
      displayLarge: HoppinType.display.copyWith(color: c.textHi),
      displayMedium: HoppinType.display.copyWith(color: c.textHi),
      displaySmall: HoppinType.headline.copyWith(color: c.textHi),
      headlineLarge: HoppinType.headline.copyWith(color: c.textHi),
      headlineMedium: HoppinType.h1.copyWith(color: c.textHi),
      headlineSmall: HoppinType.h1.copyWith(color: c.textHi),
      titleLarge: HoppinType.h1.copyWith(color: c.textHi),
      titleMedium: HoppinType.section.copyWith(color: c.textHi),
      titleSmall: HoppinType.titleSmall.copyWith(color: c.textHi),
      bodyLarge: HoppinType.bodyLarge.copyWith(color: c.textHi),
      bodyMedium: HoppinType.body.copyWith(color: c.textHi),
      bodySmall: HoppinType.meta.copyWith(color: c.textMid),
      labelLarge: HoppinType.button.copyWith(color: c.textHi),
      labelMedium: HoppinType.meta.copyWith(color: c.textMid),
      labelSmall: HoppinType.metaSmall.copyWith(color: c.textMid),
    );

    final r10 = BorderRadius.circular(HoppinRadii.card);
    final r12 = BorderRadius.circular(HoppinRadii.control);
    // HoppinRadii.input (8) is now unreferenced by the theme: inputs speak the
    // control radius like everything else. The token stays for un-converted
    // components and is pruned with them.
    // Figma buttons/chips use the 12px control radius.
    final buttonShape = RoundedRectangleBorder(borderRadius: r12);
    final buttonText = HoppinType.button;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Adaptive density compacts desktop web — the demo windows are
      // phone-shaped, so pin standard density.
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: c.canvas,
      splashFactory: InkRipple.splashFactory,
      textTheme: textTheme,
      appBarTheme: AppBarThemeData(
        backgroundColor: c.canvas,
        foregroundColor: c.textHi,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: HoppinType.title.copyWith(color: c.textHi),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        // A stock Material Card gets no HoppinShadows (that is HopCard's job),
        // so it keeps its hairline in BOTH themes — it has nothing else to
        // separate it from the canvas. `cardBorder` is for the surfaces that do
        // carry a shadow and therefore only need a line in dark.
        shape: RoundedRectangleBorder(
          borderRadius: r10,
          side: BorderSide(color: c.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          minimumSize: const Size(64, 52),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textHi,
          side: BorderSide(color: outline),
          minimumSize: const Size(64, 52),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: buttonText,
        ),
      ),
      // Inputs speak the CONTROL radius (12), like every other control in the
      // system. They were the last thing on the 8pt legacy radius, which put a
      // third corner language on screens that already had cards at 10 and
      // buttons at 12 — a tell you cannot name but can always feel.
      //
      // The resting edge is `outline`, not `hairline`. A hairline is for
      // DIVIDING (a line between two things that are already there); an input is
      // an INVITATION, and it has to announce its own edge — especially in dark,
      // where the #2A2F42 hairline against a #191D2E fill was a field you had to
      // hunt for.
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: c.card,
        border: OutlineInputBorder(
          borderRadius: r12,
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: r12,
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: r12,
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: r12,
          borderSide: BorderSide(color: c.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: r12,
          borderSide: BorderSide(color: c.error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        side: BorderSide(color: c.hairline),
        shape: const StadiumBorder(),
        labelStyle: HoppinType.label.copyWith(color: c.textHi),
      ),
      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? c.raised : c.card,
        elevation: 0,
        modalBarrierColor: c.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(HoppinRadii.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? c.raised : c.textHi,
        contentTextStyle: HoppinType.bodySmall.copyWith(
          color: dark ? c.textHi : c.canvas,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: r10),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
      listTileTheme: ListTileThemeData(
        iconColor: c.textMid,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HoppinSpacing.gutter,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: r10),
      ),
      extensions: [c, HoppinMotion.standard],
    );
  }
}
