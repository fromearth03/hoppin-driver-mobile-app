import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/src/tokens/primitives.dart';

void main() {
  test('Figma primary and secondary hex are exact', () {
    expect(HoppinPrimitives.ink, const Color(0xFF181C3A));
    expect(HoppinPrimitives.red, const Color(0xFFE33236));
    expect(HoppinPrimitives.alertRed, const Color(0xFFFF2E2E));
    expect(HoppinPrimitives.canvasLight, const Color(0xFFF6FAFC));
    expect(HoppinPrimitives.cardLight, const Color(0xFFFFFFFF));
    expect(HoppinPrimitives.selectedTintLight, const Color(0xFFF6F7FF));
    expect(HoppinPrimitives.successGreen, const Color(0xFF22C55E));
    expect(HoppinPrimitives.successSubtleLight, const Color(0xFFDDFEF3));
    expect(HoppinPrimitives.alertSurfaceLight, const Color(0xFFFFF3F3));
  });
}
