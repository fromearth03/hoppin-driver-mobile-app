import 'package:flutter/material.dart';

import '../theme/context_extension.dart';
import 'hop_button.dart';

/// A confirm/cancel decision popup (Figma: Cancel ride, Log out).
///
/// A bottom-anchored white sheet with a top radius of `radii.pillSmall` (20)
/// presented over the scrim-token barrier. Shows a [title], optional [message],
/// and a primary confirm action over a ghost cancel action. Use
/// [HopPopup.confirm] to present it and await the boolean result — `true` on
/// confirm, `false` on cancel, `null` if dismissed by the scrim.
class HopPopup extends StatelessWidget {
  /// Creates the popup surface. Prefer [HopPopup.confirm] to present it.
  const HopPopup({
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    this.message,
    this.destructive = false,
    super.key,
  });

  /// Headline question ("Cancel ride?").
  final String title;

  /// Optional supporting body.
  final String? message;

  /// Confirm action label.
  final String confirmLabel;

  /// Cancel action label.
  final String cancelLabel;

  /// When true the confirm action paints the red (destructive) variant.
  final bool destructive;

  /// Presents a [HopPopup] as a modal bottom sheet over the scrim and resolves
  /// to `true` (confirm), `false` (cancel), or `null` (scrim-dismissed).
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required String cancelLabel,
    String? message,
    bool destructive = false,
  }) {
    final colors = context.hoppin.colors;
    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      barrierColor: colors.scrim,
      builder: (_) => HopPopup(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(hoppin.radii.pillSmall),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hoppin.spacing.gutter,
          hoppin.spacing.gutter,
          hoppin.spacing.gutter,
          hoppin.spacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: hoppin.type.section.copyWith(color: colors.textHi),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              SizedBox(height: hoppin.spacing.sm),
              Text(
                message!,
                style: hoppin.type.meta.copyWith(color: colors.textMid),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: hoppin.spacing.lg),
            if (destructive)
              HopButton.red(
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true),
              )
            else
              HopButton.primary(
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            SizedBox(height: hoppin.spacing.sm),
            HopButton.ghost(
              label: cancelLabel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
