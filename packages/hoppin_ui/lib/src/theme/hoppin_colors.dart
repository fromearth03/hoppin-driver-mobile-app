import 'package:flutter/material.dart';

/// Semantic colour roles for Hoppin surfaces, carried on every [ThemeData]
/// as a [ThemeExtension] so widgets read brand colour via
/// `context.hoppin.colors` instead of raw hex or bare [ColorScheme] lanes.
///
/// [lerp] is implemented field-by-field so light/dark theme switches animate.
class HoppinColors extends ThemeExtension<HoppinColors> {
  const HoppinColors({
    required this.accent,
    required this.onAccent,
    required this.accentSubtle,
    required this.canvas,
    required this.card,
    required this.selectedTint,
    required this.selectedBorder,
    required this.raised,
    required this.hairline,
    required this.textHi,
    required this.textMid,
    required this.success,
    required this.successSubtle,
    required this.warn,
    required this.warnSubtle,
    required this.error,
    required this.errorSubtle,
    required this.plateBg,
    required this.plateText,
    required this.scrim,
    required this.glass,
    required this.glassSheet,
    required this.glassEdge,
    required this.glassSpecular,
    required this.glassUnderRim,
    required this.glassShadow,
    required this.cardBorder,
  });

  /// Brand accent: the Figma navy ink (#181C3A) in light; the derived
  /// navy-on-dark lift in dark. One accent across both apps in the revamp.
  final Color accent;

  /// Foreground on [accent] fills.
  final Color onAccent;

  /// Accent at 12% over canvas, precomputed opaque — chip/tint surfaces.
  final Color accentSubtle;

  /// App background.
  final Color canvas;

  /// Resting card surface.
  final Color card;

  /// Selected card/list tint — Figma #F6F7FF (light).
  final Color selectedTint;

  /// 1px border on a selected card — Figma navy ink.
  final Color selectedBorder;

  /// Elevated surface (sheets, snackbars in dark).
  final Color raised;

  /// 1px borders and dividers — the hairline-first surface language.
  final Color hairline;

  /// High-emphasis text. Never pure white in dark.
  final Color textHi;

  /// Mid-emphasis text.
  final Color textMid;

  /// Positive money/status.
  final Color success;

  /// [success] at 12% over canvas, opaque.
  final Color successSubtle;

  /// Caution — ochre, not amber.
  final Color warn;

  /// [warn] at 12% over canvas, opaque.
  final Color warnSubtle;

  /// Failure/destructive.
  final Color error;

  /// [error] at 12% over canvas, opaque.
  final Color errorSubtle;

  /// Number-plate chip background (yellow rear plate light, white plate dark).
  final Color plateBg;

  /// Number-plate characters.
  final Color plateText;

  /// Modal barrier — warm near-black at 40% (light) / 55% (dark).
  final Color scrim;

  /// The frosted-chrome fill: the floating top pill and the bottom nav.
  ///
  /// **Deliberately translucent** — unlike every other colour here, which
  /// precomputes its blend against [canvas]. This one is painted OVER a live
  /// `BackdropFilter`, and the alpha is the whole point: it is what lets the
  /// page scroll through and read as glass. Paint it opaque and you have a
  /// tinted card with an expensive no-op behind it.
  ///
  /// Always use it with a blur. A translucent fill with nothing behind it is
  /// the classic failure of this style.
  final Color glass;

  /// The frosted fill of a modal SHEET — the same material as [glass], denser.
  ///
  /// 🔴 Not a duplicate token and not a taste variant: a sheet does a harder
  /// legibility job than the chrome does. The bars carry titles and icons; a
  /// sheet carries mid-emphasis body copy that someone reads. Measured over the
  /// worst backdrop a sheet can float over, [glass]'s 72% fill puts dark-theme
  /// secondary text at **3.94:1 — under AA**. This tier is 86%, which clears the
  /// floor while still showing 14% of the blurred page through.
  ///
  /// Do not collapse this into [glass]. One material, two duties; the duty sets
  /// the alpha, and the floor sets the duty.
  final Color glassSheet;

  /// The 1px rim on a [glass] surface — a bright catch-light in light, a low
  /// white lift in dark. Frosted panes catch light on their edge; without it
  /// the bar has no boundary and dissolves into whatever it floats over.
  ///
  /// 🔴 Dark's rim shipped at 14% against light's 60% — a 4.3x asymmetry with no
  /// reason behind it, which measured 1.56:1 against the dark pane and was, in
  /// practice, not there. An optical material is defined by how its edges
  /// behave. Now 32% / 2.88:1. See the primitives note for the full ladder and
  /// why it stops short of the 40-50% that looks like a drawn outline.
  final Color glassEdge;

  /// The highlight on a [glass] pane's top FACE — light reflected off the slab,
  /// as distinct from [glassEdge], which is light caught on its rim.
  ///
  /// 🔴 A token and not a factor of [glassEdge], which is how it used to be
  /// derived (`glassEdge * 0.45`). That coupling silently dragged dark's
  /// specular to white @6.3% — below the ~10% where a gradient reads as light
  /// rather than as banding — so one conservative rim value broke two optical
  /// properties at once. A rim and a specular answer to different physics; they
  /// get different tokens.
  final Color glassSpecular;

  /// The DARK counter-rim on a [glass] pane's bottom arc.
  ///
  /// A pane lit from above catches light on its top edge and turns its own
  /// thickness into shadow on the bottom one. Without this the rim is a uniform
  /// outline, and a uniform outline is a drawn rectangle — the near/far
  /// asymmetry is what makes the eye read a slab with two faces.
  final Color glassUnderRim;

  /// The cast of a floating [glass] surface. Wider, softer and more diffuse
  /// than a resting card's, and materially deeper in dark (a 10%-black shadow
  /// over a #0F1220 canvas is invisible). Feed it to [HoppinShadows.glass].
  final Color glassShadow;

  /// The RESTING edge of a [card].
  ///
  /// 🔴 In light this is transparent, and that is correct: a white card on a
  /// cool-white canvas is separated by its shadow, and a border on top of that
  /// would only muddy it.
  ///
  /// In dark it is a hairline, and that is not a stylistic preference — it is a
  /// repair. **Shadows do not work on dark surfaces.** The resting card shadow
  /// is 8% black; painted over a #0F1220 canvas it is, to the eye, nothing at
  /// all. So in dark the cards had NO separation from the page whatsoever: a
  /// #191D2E card on a #0F1220 canvas is a 6% luminance step and a shadow that
  /// cannot be seen. The whole surface hierarchy — which reads beautifully in
  /// light — was flat.
  ///
  /// Dark themes carry elevation with a LINE and a lifted fill, not with a cast.
  /// This is that line.
  final Color cardBorder;

  @override
  HoppinColors copyWith({
    Color? accent,
    Color? onAccent,
    Color? accentSubtle,
    Color? canvas,
    Color? card,
    Color? selectedTint,
    Color? selectedBorder,
    Color? raised,
    Color? hairline,
    Color? textHi,
    Color? textMid,
    Color? success,
    Color? successSubtle,
    Color? warn,
    Color? warnSubtle,
    Color? error,
    Color? errorSubtle,
    Color? plateBg,
    Color? plateText,
    Color? scrim,
    Color? glass,
    Color? glassSheet,
    Color? glassEdge,
    Color? glassSpecular,
    Color? glassUnderRim,
    Color? glassShadow,
    Color? cardBorder,
  }) {
    return HoppinColors(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      selectedTint: selectedTint ?? this.selectedTint,
      selectedBorder: selectedBorder ?? this.selectedBorder,
      raised: raised ?? this.raised,
      hairline: hairline ?? this.hairline,
      textHi: textHi ?? this.textHi,
      textMid: textMid ?? this.textMid,
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
      warn: warn ?? this.warn,
      warnSubtle: warnSubtle ?? this.warnSubtle,
      error: error ?? this.error,
      errorSubtle: errorSubtle ?? this.errorSubtle,
      plateBg: plateBg ?? this.plateBg,
      plateText: plateText ?? this.plateText,
      scrim: scrim ?? this.scrim,
      glass: glass ?? this.glass,
      glassSheet: glassSheet ?? this.glassSheet,
      glassEdge: glassEdge ?? this.glassEdge,
      glassSpecular: glassSpecular ?? this.glassSpecular,
      glassUnderRim: glassUnderRim ?? this.glassUnderRim,
      glassShadow: glassShadow ?? this.glassShadow,
      cardBorder: cardBorder ?? this.cardBorder,
    );
  }

  @override
  HoppinColors lerp(ThemeExtension<HoppinColors>? other, double t) {
    if (other is! HoppinColors) {
      return this;
    }
    return HoppinColors(
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      selectedTint: Color.lerp(selectedTint, other.selectedTint, t)!,
      selectedBorder: Color.lerp(selectedBorder, other.selectedBorder, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      textHi: Color.lerp(textHi, other.textHi, t)!,
      textMid: Color.lerp(textMid, other.textMid, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnSubtle: Color.lerp(warnSubtle, other.warnSubtle, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorSubtle: Color.lerp(errorSubtle, other.errorSubtle, t)!,
      plateBg: Color.lerp(plateBg, other.plateBg, t)!,
      plateText: Color.lerp(plateText, other.plateText, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassSheet: Color.lerp(glassSheet, other.glassSheet, t)!,
      glassEdge: Color.lerp(glassEdge, other.glassEdge, t)!,
      glassSpecular: Color.lerp(glassSpecular, other.glassSpecular, t)!,
      glassUnderRim: Color.lerp(glassUnderRim, other.glassUnderRim, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
    );
  }
}
