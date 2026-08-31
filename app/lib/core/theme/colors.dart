import 'package:flutter/material.dart';

/// Palette derived from the Figma pack. Light mode is the only theme we
/// ship — drivers use this in a car, in daylight — but every colour is a
/// token so a future dark mode is this file, not twenty-five screens.
///
/// Never write a raw Color() in a widget.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF2E0B78); // deep indigo
  static const primaryDark = Color(0xFF1E0550);

  /// The lighter violet the brand gradient starts from, top of the panel.
  static const primaryLight = Color(0xFF4310AE);

  /// The muted lilac the design uses for a primary button. Notably softer
  /// than [primary] — it reads as an action, not as chrome.
  static const buttonPrimary = Color(0xFF9585C0);

  /// The soft pink the design gives a "go back" action. Visible, but never
  /// mistakable for the primary button beside it.
  static const buttonMuted = Color(0xFFF6D9DC);
  static const accent = Color(0xFFF07A21); // orange, primary actions

  static const background = Color(0xFFF5F5F7); // app ground
  static const surface = Color(0xFFFFFFFF); // cards
  static const border = Color(0xFFE3E3E8);

  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B6B7B);
  static const textDisabled = Color(0xFFA0A0B0);

  static const positive = Color(0xFF2BA84A); // online, credits
  static const negative = Color(0xFFD64545); // penalties, debits, blocked
  static const warning = Color(0xFFE8A33D); // expiring, pending review
  static const info = Color(0xFF3D7FE8);
}
