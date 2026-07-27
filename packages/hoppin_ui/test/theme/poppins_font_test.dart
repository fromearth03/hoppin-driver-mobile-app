import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';

void main() {
  test('HoppinType.h1 uses Poppins from the hoppin_ui package', () {
    // When a TextStyle sets `package:`, Flutter prefixes the resolved family
    // as `packages/<pkg>/<family>`.
    expect(HoppinType.h1.fontFamily, 'packages/hoppin_ui/Poppins');
    expect(HoppinType.h1.fontWeight, FontWeight.w600);
  });
}
