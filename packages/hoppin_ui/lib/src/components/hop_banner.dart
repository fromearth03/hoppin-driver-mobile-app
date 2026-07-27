import 'package:flutter/material.dart';

import '../theme/context_extension.dart';

enum _HopBannerTone { error, notice, success }

/// The Hoppin brand banner — the designed replacement for the stock
/// status banner. Hairline-first: a tone-Subtle surface with a 3px leading
/// accent bar in the tone colour, never a heavy fill, never an icon-emoji.
///
/// Tones map straight onto the semantic colour roles:
/// - [HopBanner.error] — `colors.error` bar over `colors.errorSubtle`.
/// - [HopBanner.notice] — the lane accent over `colors.accentSubtle`.
/// - [HopBanner.success] — `colors.success` over `colors.successSubtle`.
///
/// Provide [actionLabel] + [onAction] for an inline ghost-style action
/// (e.g. Retry); without one the banner is message-only and ink-free.
/// Pure presentation: state in, events out.
class HopBanner extends StatelessWidget {
  /// Error tone — failures the user can usually act on.
  const HopBanner.error({
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : _tone = _HopBannerTone.error;

  /// Notice tone — neutral heads-up in the lane accent.
  const HopBanner.notice({
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : _tone = _HopBannerTone.notice;

  /// Success tone — confirmations (promo applied, place saved).
  const HopBanner.success({
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : _tone = _HopBannerTone.success;

  /// The banner message, set in bodySmall textHi.
  final String message;

  /// Optional inline action label; renders only with [onAction].
  final String? actionLabel;

  /// Fired when the action is tapped.
  final VoidCallback? onAction;

  final _HopBannerTone _tone;

  static const double _barWidth = 3;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final colors = hoppin.colors;

    final (tone, surface) = switch (_tone) {
      _HopBannerTone.error => (colors.error, colors.errorSubtle),
      _HopBannerTone.notice => (colors.accent, colors.accentSubtle),
      _HopBannerTone.success => (colors.success, colors.successSubtle),
    };

    final hasAction = actionLabel != null && onAction != null;
    final radius = BorderRadius.circular(hoppin.radii.card);

    return Semantics(
      container: true,
      liveRegion: true,
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(color: surface, borderRadius: radius),
          // The stretch Row needs a finite height even in unbounded
          // contexts (list bodies) — the banner owns that, not call sites.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The tone lives in the leading edge, not the fill — the
                // hairline-family accent bar.
                SizedBox(
                  width: _barWidth,
                  child: ColoredBox(color: tone),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: hoppin.spacing.md,
                      vertical: hoppin.spacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            message,
                            style: hoppin.type.bodySmall
                                .copyWith(color: colors.textHi),
                          ),
                        ),
                        if (hasAction) ...[
                          SizedBox(width: hoppin.spacing.sm),
                          _BannerAction(
                            label: actionLabel!,
                            tone: tone,
                            onTap: onAction!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact ghost-style action: tone-coloured label, ink on tap, no border —
/// banner-sized rather than the full 52px [HopButton].
class _BannerAction extends StatelessWidget {
  const _BannerAction({
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hoppin = context.hoppin;
    final radius = BorderRadius.circular(hoppin.radii.input);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hoppin.spacing.sm,
            vertical: hoppin.spacing.xs,
          ),
          child: Text(
            label,
            style: hoppin.type.label.copyWith(
              color: tone,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
