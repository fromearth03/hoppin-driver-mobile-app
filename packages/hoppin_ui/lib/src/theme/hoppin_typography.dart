import 'package:flutter/material.dart';

/// The Hoppin type scale — Poppins throughout, sized to the Figma
/// "Passenger View" frames. One family; weight carries hierarchy.
///
/// Figma-named roles (`h1`/`section`/`body`/…) are the R1 vocabulary. The
/// legacy Blackcab names (`display`/`title`/`moneyHero`/…) are retained as
/// aliases repointed onto Poppins so existing consumers keep compiling
/// through the revamp; they are pruned once every screen is converted.
abstract final class HoppinType {
  static const String _f = 'Poppins';
  static const String _pkg = 'hoppin_ui';

  // ── Figma roles (R1) ──────────────────────────────────────────────────
  static const h1 = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );
  static const section = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  static const titleSmall = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );
  static const bodyLarge = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 18,
    fontWeight: FontWeight.w400,
  );
  static const body = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );
  static const bodyMedium = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
  static const meta = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  static const metaSmall = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
  static const button = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 18,
    fontWeight: FontWeight.w500,
  );
  static const buttonLarge = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.22,
  );
  static const fareTotal = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );

  // ── Legacy aliases (repointed to Poppins; pruned post-conversion) ──────
  static const display = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 44,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.0,
  );
  static const headline = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );
  static const title = section;
  static const bodySmall = meta;
  static const label = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
  static const labelSmall = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );
  static const moneyHero = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const moneyTitle = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numeral = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const numeralCaption = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const ledger = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures(), FontFeature.slashedZero()],
  );
  static const plate = TextStyle(
    fontFamily: _f,
    package: _pkg,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
