import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import 'hoppin_colors.dart';
import 'hoppin_motion.dart';
import 'hoppin_typography.dart';

/// `context.hoppin` — the one way app code consumes design tokens.
///
/// ```dart
/// final c = context.hoppin.colors;
/// AnimatedContainer(duration: context.hoppin.motion.quick, ...);
/// Padding(padding: EdgeInsets.all(context.hoppin.spacing.gutter), ...);
/// ```
extension HoppinContextX on BuildContext {
  /// Token surface for this context's [Theme].
  HoppinTokens get hoppin => HoppinTokens(this);
}

/// Zero-allocation view over the Hoppin token surfaces. The colour and
/// motion tokens come off the ambient [Theme]; spacing/radii/type are
/// brightness-invariant constants exposed through const views.
extension type HoppinTokens(BuildContext _context) {
  /// Semantic colours from the ambient theme.
  HoppinColors get colors => Theme.of(_context).extension<HoppinColors>()!;

  /// Motion tokens from the ambient theme.
  HoppinMotion get motion => Theme.of(_context).extension<HoppinMotion>()!;

  /// Spacing scale ([HoppinSpacing] statics).
  HoppinSpacingView get spacing => const HoppinSpacingView();

  /// Corner radii ([HoppinRadii] statics).
  HoppinRadiiView get radii => const HoppinRadiiView();

  /// Type scale ([HoppinType] statics).
  HoppinTypeView get type => const HoppinTypeView();

  /// Frosted-chrome geometry ([HoppinChrome] statics) — the floating pill, the
  /// concentric avatar, the blur sigma, and the scroll padding a tab owes the
  /// chrome it scrolls under.
  HoppinChromeView get chrome => const HoppinChromeView();
}

/// Instance passthrough over [HoppinSpacing] so `context.hoppin.spacing.md`
/// reads naturally. Const-canonicalized — no per-access allocation.
final class HoppinSpacingView {
  const HoppinSpacingView();

  double get xs => HoppinSpacing.xs;
  double get sm => HoppinSpacing.sm;
  double get md => HoppinSpacing.md;
  double get lg => HoppinSpacing.lg;
  double get gutter => HoppinSpacing.gutter;
  double get xl => HoppinSpacing.xl;
}

/// Instance passthrough over [HoppinChrome] — the frosted-chrome geometry.
/// Every number here is DERIVED from [HoppinChrome.barHeight] /
/// [HoppinChrome.avatarSize]; read them, never re-spell them.
final class HoppinChromeView {
  const HoppinChromeView();

  /// The floating pill's height.
  double get barHeight => HoppinChrome.barHeight;

  /// The avatar's diameter.
  double get avatarSize => HoppinChrome.avatarSize;

  /// Half the bar height — a TRUE pill.
  double get pillRadius => HoppinChrome.pillRadius;

  /// Half the avatar.
  double get avatarRadius => HoppinChrome.avatarRadius;

  /// The uniform gap between the two arcs — `pillRadius - avatarRadius`.
  double get avatarInset => HoppinChrome.avatarInset;

  /// Gap from the screen edge to the floating pill.
  double get pillMargin => HoppinChrome.pillMargin;

  /// Blur sigma shared by both frosted bars.
  double get blurSigma => HoppinChrome.blurSigma;

  /// How much chroma the glass restores after the blur averaged it away.
  double get saturation => HoppinChrome.saturation;

  /// The luminance-preserving colour matrix that applies [saturation].
  List<double> get saturationMatrix => HoppinChrome.saturationMatrix();

  /// Top padding a tab owes the floating pill it scrolls under.
  double get scrollPaddingTop => HoppinChrome.scrollPaddingTop;

  /// Bottom padding a tab owes the anchored glass nav it scrolls under.
  double get scrollPaddingBottom => HoppinChrome.scrollPaddingBottom;
}

/// Scroll padding that clears the frosted chrome.
///
/// 🔴 **The bug this exists to prevent.** Once the shell layers the bars OVER
/// the content (which is the only way a `BackdropFilter` has anything to blur),
/// a `ListView` starting at y=0 starts UNDERNEATH the floating pill. Its first
/// row is not merely dimmed — it is unreachable, because you cannot scroll UP
/// past the top of a scroll view. Same story at the bottom, under the nav. A
/// beautiful bar that permanently hides the first list item is a bug, not a
/// style.
///
/// The room CANNOT be taken by shrinking the viewport (a `Padding` around the
/// branch would rebuild the old `Column`: nothing would pass under the bars and
/// the blur would go back to sampling nothing). It has to be given to the
/// SCROLL VIEW, as content inset, while the viewport stays full-bleed.
///
/// The shell publishes the room it is occupying as `MediaQuery.padding`; this
/// reads it back. Off-shell screens have no such injection, so they get the
/// plain safe-area inset and nothing extra — the same call site is correct in
/// both places, which is the point.
extension HoppinScrollPaddingX on BuildContext {
  /// The padding a scroll view owes the chrome it scrolls beneath, plus
  /// [horizontal] / [top] / [bottom] of the screen's own.
  EdgeInsets chromeScrollPadding({
    double horizontal = 0,
    double top = 0,
    double bottom = 0,
  }) {
    final inset = MediaQuery.paddingOf(this);
    return EdgeInsets.fromLTRB(
      horizontal,
      inset.top + top,
      horizontal,
      inset.bottom + bottom,
    );
  }
}

/// Instance passthrough over [HoppinRadii].
final class HoppinRadiiView {
  const HoppinRadiiView();

  double get card => HoppinRadii.card;

  /// Figma control radius (buttons, chips, OTP boxes, capsules) — 12.
  double get control => HoppinRadii.control;

  /// Figma modal-sheet top radius — 20.
  double get pillSmall => HoppinRadii.pillSmall;

  /// Fully-rounded pill radius — 100.
  double get pill => HoppinRadii.pill;

  double get input => HoppinRadii.input;
  double get sheet => HoppinRadii.sheet;
  double get plate => HoppinRadii.plate;
}

/// Instance passthrough over [HoppinType].
final class HoppinTypeView {
  const HoppinTypeView();

  // ── Figma roles (R1) ──────────────────────────────────────────────────
  /// Screen title / top-bar title — Poppins SemiBold 22.
  TextStyle get h1 => HoppinType.h1;

  /// Section heading — Poppins SemiBold 20.
  TextStyle get section => HoppinType.section;

  /// Row/value emphasis — Poppins w400 18.
  TextStyle get bodyLarge => HoppinType.bodyLarge;

  /// Card name / medium emphasis — Poppins w500 16.
  TextStyle get bodyMedium => HoppinType.bodyMedium;

  /// Supporting copy — Poppins w400 14.
  TextStyle get meta => HoppinType.meta;

  /// Caption — Poppins w400 12.
  TextStyle get metaSmall => HoppinType.metaSmall;

  /// Button label — Poppins w500 18.
  TextStyle get button => HoppinType.button;

  /// Large CTA label — Poppins w500 22.
  TextStyle get buttonLarge => HoppinType.buttonLarge;

  /// Fare total — Poppins SemiBold 22.
  TextStyle get fareTotal => HoppinType.fareTotal;

  // ── Legacy aliases (repointed to Poppins; pruned post-conversion) ──────
  TextStyle get display => HoppinType.display;
  TextStyle get headline => HoppinType.headline;
  TextStyle get title => HoppinType.title;
  TextStyle get titleSmall => HoppinType.titleSmall;
  TextStyle get body => HoppinType.body;
  TextStyle get bodySmall => HoppinType.bodySmall;
  TextStyle get label => HoppinType.label;
  TextStyle get labelSmall => HoppinType.labelSmall;
  TextStyle get moneyHero => HoppinType.moneyHero;
  TextStyle get moneyTitle => HoppinType.moneyTitle;
  TextStyle get numeral => HoppinType.numeral;
  TextStyle get numeralCaption => HoppinType.numeralCaption;
  TextStyle get ledger => HoppinType.ledger;
  TextStyle get plate => HoppinType.plate;
}
