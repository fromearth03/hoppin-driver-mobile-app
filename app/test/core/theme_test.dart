import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoppin_driver/core/theme/app_theme.dart';
import 'package:hoppin_driver/core/theme/colors.dart';

void main() {
  test('theme is light and uses the brand primary', () {
    final theme = appTheme();
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, AppColors.primary);
  });

  test('semantic tokens are distinct so states read differently', () {
    expect(AppColors.positive, isNot(AppColors.negative));
    expect(AppColors.warning, isNot(AppColors.negative));
  });

  test('scaffold background is the app surface, not pure white', () {
    expect(appTheme().scaffoldBackgroundColor, AppColors.background);
    expect(AppColors.background, isNot(const Color(0xFFFFFFFF)));
  });
}
