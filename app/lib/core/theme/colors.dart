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

  // Ground, ink and hairlines — sampled from the Figma exports, not eyed.
  static const background = Color(0xFFEFEFEF); // app ground
  static const surface = Color(0xFFFFFFFF); // cards
  static const border = Color(0xFFDBDBDB);

  static const textPrimary = Color(0xFF181C3A); // the design's navy ink
  static const textSecondary = Color(0xFF585B71);
  static const textDisabled = Color(0xFFA8A9B5);

  static const positive = Color(0xFF23B386); // online, credits, good trends
  static const negative = Color(0xFFD64545); // debits, destructive actions
  static const warning = Color(0xFFF27201); // expiring, pending review
  static const info = Color(0xFF6176FE);

  /// The Stats tiles' saturated set, sampled from the design. [statRed] is
  /// the coral of the cancellation tile — deliberately not [negative],
  /// which stays the deeper crimson of money leaving and things breaking.
  static const statPurple = Color(0xFF522CF2);
  static const statRed = Color(0xFFFD5368);

  /// The design's star gold — brighter than [warning]'s amber.
  static const gold = Color(0xFFFEC209);

  /// The floating tab pill's grey, laid translucent over its backdrop blur.
  static const navPill = Color(0xFF7B7777);

  /// Pale grounds behind status icons and expanded status panels.
  static const tintRed = Color(0xFFFDE6EA);
  static const tintAmber = Color(0xFFFCEEDD);
  static const tintMint = Color(0xFFE5F5F0);
}
