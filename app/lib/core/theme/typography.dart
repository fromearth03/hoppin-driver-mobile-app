import 'package:flutter/material.dart';
import 'colors.dart';

/// Type scale. Named by role rather than size so a screen asks for what a
/// piece of text *is*, not how big it happens to be.
class AppText {
  AppText._();

  static const display = TextStyle(
      fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
  static const title = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const heading = TextStyle(
      fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
  static const body = TextStyle(
      fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary);
  static const bodySecondary = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary);
  static const caption = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary);
  static const money = TextStyle(
      fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary);
}
