import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

void main() {
  test('Figma radii + card shadow', () {
    expect(HoppinRadii.card, 10.0);
    expect(HoppinRadii.control, 12.0);
    expect(HoppinRadii.pill, 100.0);
    final s = HoppinShadows.card.first;
    expect(s.offset, const Offset(2, 2));
    expect(s.blurRadius, 6);
    expect(s.spreadRadius, 1);
  });

  group('the frosted-chrome geometry', () {
    // The concentric identity is asserted in full — against the REAL painted
    // rects — in components/hop_top_bar_test. It is restated here at the TOKEN
    // level because this is where it would actually get broken: somebody tuning
    // the bar height has no reason to be reading a component test.
    test('every number derives from barHeight and avatarSize', () {
      expect(HoppinChrome.pillRadius, HoppinChrome.barHeight / 2);
      expect(HoppinChrome.avatarRadius, HoppinChrome.avatarSize / 2);
      expect(
        HoppinChrome.avatarInset,
        HoppinChrome.pillRadius - HoppinChrome.avatarRadius,
      );
    });

    test('the shipped values are 64/48 → 32/24/8', () {
      expect(HoppinChrome.barHeight, 64.0);
      expect(HoppinChrome.avatarSize, 48.0);
      expect(HoppinChrome.pillRadius, 32.0);
      expect(HoppinChrome.avatarRadius, 24.0);
      expect(HoppinChrome.avatarInset, 8.0);
    });

    test('a tab reserves enough scroll padding to clear BOTH bars', () {
      // Content scrolls UNDER the glass — which means a tab that reserves no
      // padding parks its first row permanently beneath the pill. A beautiful
      // bar that hides the first list item is a bug, not a style.
      expect(
        HoppinChrome.scrollPaddingTop,
        greaterThan(HoppinChrome.barHeight),
        reason: 'the top padding must clear the pill AND the air it floats in',
      );
      expect(
        HoppinChrome.scrollPaddingBottom,
        greaterThan(HoppinChrome.barHeight),
      );
    });

    test('the blur sigma is one constant, shared by both bars', () {
      // Two sigmas would read as two different materials.
      expect(HoppinChrome.blurSigma, greaterThan(0));
    });
  });

  group('the glass shadow', () {
    test('is a FLOATING cast: soft, wide, and not offset diagonally', () {
      final cast = HoppinShadows.glass(const Color(0x33000000));
      expect(cast, hasLength(2), reason: 'a contact layer AND an ambient one');

      final ambient = cast.first;
      expect(
        ambient.offset.dx,
        0,
        reason:
            'a floating pill has no attached edge — a diagonal cast (which is '
            'right for a resting card) makes it look glued to the corner it '
            'leans away from',
      );
      expect(
        ambient.offset.dy,
        greaterThan(0),
        reason: 'light comes from above',
      );
      expect(
        ambient.blurRadius,
        greaterThan(HoppinShadows.card.first.blurRadius),
        reason:
            'the pill is held further off the page than a resting card, so its '
            'cast is softer and wider',
      );
    });

    test('the contact layer is fainter than the ambient one', () {
      final cast = HoppinShadows.glass(const Color(0x66000000));
      expect(cast.last.color.a, lessThan(cast.first.color.a));
    });
  });
}
