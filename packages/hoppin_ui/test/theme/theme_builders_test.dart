import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_ui/hoppin_ui.dart';
import 'package:hoppin_ui/src/tokens/primitives.dart';

void main() {
  test('rider light theme carries Figma tokens and Poppins', () {
    final t = HoppinTheme.riderLight();
    final c = t.extension<HoppinColors>()!;
    expect(c.canvas, HoppinPrimitives.canvasLight);
    expect(c.accent, HoppinPrimitives.ink);
    expect(t.scaffoldBackgroundColor, HoppinPrimitives.canvasLight);
    expect(t.textTheme.bodyMedium?.fontFamily, 'packages/hoppin_ui/Poppins');
    expect(t.colorScheme.primary, HoppinPrimitives.ink);
  });

  test('rider dark theme canvas is the dark ramp', () {
    final t = HoppinTheme.riderDark();
    expect(t.extension<HoppinColors>()!.canvas, HoppinPrimitives.canvasDark);
  });
}
