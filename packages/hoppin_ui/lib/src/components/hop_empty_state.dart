import 'package:flutter/material.dart';

import '../theme/context_extension.dart';
import 'hop_button.dart';

/// The designed empty state — typography-led per the locked surface
/// language: a Geist-600 headline over a textMid supporting line, centre
/// aligned, with an optional [HopButton]-family action. Banned by design:
/// emoji, mascots, illustration placeholders.
///
/// Set [compact] for inline list-body use — tighter paddings and the
/// smaller headline step.
class HopEmptyState extends StatelessWidget {
  /// Creates an empty state with a headline and supporting line.
  const HopEmptyState({
    required this.headline,
    required this.supporting,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  /// The one-line answer to "why is this empty?" — Geist 600, textHi.
  final String headline;

  /// The softer follow-up — what will appear here, or what to do next.
  final String supporting;

  /// Optional action label; renders only with [onAction].
  final String? actionLabel;

  /// Fired when the action is tapped.
  final VoidCallback? onAction;

  /// Tighter inline treatment for list bodies.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;
    final spacing = hoppin.spacing;
    final hasAction = actionLabel != null && onAction != null;

    final headlineStyle = (compact ? hoppin.type.titleSmall : hoppin.type.title)
        .copyWith(color: colors.textHi);
    final supportingStyle =
        (compact ? hoppin.type.bodySmall : hoppin.type.body)
            .copyWith(color: colors.textMid);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.gutter,
        vertical: compact ? spacing.md : spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(headline, textAlign: TextAlign.center, style: headlineStyle),
          SizedBox(height: compact ? spacing.xs : spacing.sm),
          Text(
            supporting,
            textAlign: TextAlign.center,
            style: supportingStyle,
          ),
          if (hasAction) ...[
            SizedBox(height: compact ? spacing.md : spacing.lg),
            HopButton.secondary(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
          ],
        ],
      ),
    );
  }
}
