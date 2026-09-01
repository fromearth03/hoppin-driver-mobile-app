import 'package:flutter/material.dart';
import 'colors.dart';

/// Type scale. Named by role rather than size so a screen asks for what a
/// piece of text *is*, not how big it happens to be.
///
/// Everything is set in Baloo 2, the design's rounded family — bundled, so
/// the app renders identically offline, in tests, and on every platform.
class AppText {
  AppText._();

  /// The design family. Also set as [ThemeData.fontFamily], so Material
  /// widgets that build their own styles (buttons, app bars) match.
  static const fontFamily = 'Baloo2';

  static const display = TextStyle(
      fontFamily: fontFamily,
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary);
  static const title = TextStyle(
      fontFamily: fontFamily,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary);
  static const heading = TextStyle(
      fontFamily: fontFamily,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary);
  static const body = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary);
  static const bodySecondary = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary);
  static const caption = TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary);
  static const money = TextStyle(
      fontFamily: fontFamily,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary);
}
