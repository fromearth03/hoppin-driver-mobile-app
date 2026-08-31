import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

/// The three button shapes the design uses, in one place so a screen picks a
/// role rather than restating a radius and a colour.
class AppButtons {
  AppButtons._();

  static const _radius = 16.0;
  static const height = 62.0;

  /// The lilac fill. One per screen — the thing the driver came to do.
  static ButtonStyle primary() => FilledButton.styleFrom(
        backgroundColor: AppColors.buttonPrimary,
        disabledBackgroundColor: AppColors.buttonPrimary.withValues(alpha: 0.5),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      );

  /// White with a hairline border. A real action, but not the main one.
  static ButtonStyle outlined() => OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textSecondary,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      );

  /// The soft pink the design gives to "go back" — present, unmistakably
  /// secondary, and never confusable with the primary action.
  static ButtonStyle muted() => FilledButton.styleFrom(
        backgroundColor: AppColors.buttonMuted,
        foregroundColor: AppColors.textPrimary,
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      );
}

/// A full-width button at the design's height, with the spinner already
/// wired — every form in the app needs exactly this.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final ButtonStyle? style;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: AppButtons.height,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: style ?? AppButtons.primary(),
          child: busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(label),
        ),
      );
}

/// The outlined sibling of [AppButton].
class AppOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const AppOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: AppButtons.height,
        child: OutlinedButton(
          onPressed: busy ? null : onPressed,
          style: AppButtons.outlined(),
          child: busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.textSecondary),
                )
              : Text(label, style: AppText.body.copyWith(fontSize: 17)),
        ),
      );
}
