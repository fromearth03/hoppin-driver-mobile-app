import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

void main() {
  test('type scale matches Figma sizes and Poppins weights', () {
    expect(HoppinType.h1.fontSize, 22);
    expect(HoppinType.h1.fontWeight, FontWeight.w600);
    expect(HoppinType.section.fontSize, 20);
    expect(HoppinType.body.fontSize, 16);
    expect(HoppinType.fareTotal.fontWeight, FontWeight.w600);
    for (final s in [HoppinType.h1, HoppinType.body, HoppinType.button]) {
      expect(s.fontFamily, 'packages/hoppin_ui/Poppins');
    }
  });
}
