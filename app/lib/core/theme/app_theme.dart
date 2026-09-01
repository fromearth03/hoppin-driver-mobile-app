import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

/// Light only, by product decision. See the spec, §2.4.
ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    error: AppColors.negative,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: AppText.fontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppText.heading,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    // The date pickers ship as raw Material sheets otherwise — grey defaults
    // and system typography, the one part of the app the design tokens never
    // reached. Styled here once so the trips range filter, the earnings
    // report range and the onboarding expiry fields all inherit.
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.background,
      headerBackgroundColor: AppColors.primary,
      headerForegroundColor: Colors.white,
      headerHeadlineStyle: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      rangePickerBackgroundColor: AppColors.background,
      rangePickerHeaderBackgroundColor: AppColors.primary,
      rangePickerHeaderForegroundColor: Colors.white,
      rangePickerHeaderHeadlineStyle: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      rangeSelectionBackgroundColor: AppColors.primary.withValues(alpha: 0.12),
      dayStyle: AppText.body,
      weekdayStyle: AppText.caption,
      todayBorder: const BorderSide(color: AppColors.primary),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.transparent,
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.textPrimary,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        textStyle: const TextStyle(fontSize: 17),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: AppText.display,
      titleLarge: AppText.title,
      titleMedium: AppText.heading,
      bodyMedium: AppText.body,
      bodySmall: AppText.caption,
    ),
  );
}
